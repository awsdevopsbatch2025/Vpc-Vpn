# ==============================================================================
# SECTION 1: VPC INFRASTRUCTURE (4 AZs)
# ==============================================================================
module "new_vpc" {
  source  = "app.terraform.io/creditonebank/vpc-module/aws"
  version = "1.1.7"

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets  = ["10.50.64.0/24", "10.50.65.0/24", "10.50.66.0/24", "10.50.67.0/24"]
  firewall_subnets = ["10.50.67.192/28", "10.50.67.208/28", "10.50.67.224/28", "10.50.67.240/28"]
}

# ==============================================================================
# SECTION 2: SECURITY VPC INSPECTION (GWLB Endpoints)
# ==============================================================================
resource "aws_vpc_endpoint" "gwlb_endpoints" {
  count             = 4
  service_name      = var.gwlb_service_name
  vpc_id            = module.new_vpc.vpc_id
  vpc_endpoint_type = "GatewayLoadBalancer"
  
  
  subnet_ids        = [module.new_vpc.firewall_subnets[count.index]]

  tags = { Name = "gwlbe-az-${count.index}" }
}

# ==============================================================================
# SECTION 3: TRANSIT GATEWAY (TGW) CONNECTION
# ==============================================================================
resource "aws_ec2_transit_gateway_vpc_attachment" "workload_attachment" {
  subnet_ids             = module.new_vpc.private_subnets
  transit_gateway_id     = var.tgw_id
  vpc_id                 = module.new_vpc.vpc_id
  appliance_mode_support = "enable" # Required for firewall symmetry

  tags = { Name = "tgw-attach-new-workload" }
}

resource "aws_ec2_transit_gateway_route_table_association" "workload_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.workload_tgw_rt_id
}


resource "aws_ec2_transit_gateway_route_table_propagation" "workload_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.on_prem_tgw_rt_id
}

# ==============================================================================
# SECTION 4: SECURITY GROUPS
# ==============================================================================
resource "aws_security_group" "workload_sg" {
  name        = "workload-internal-sg"
  vpc_id      = module.new_vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", var.on_prem_internal_cidr] # Allows GCP Subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# SECTION 5: GCP HYBRID CONNECTIVITY (VPN)
# ==============================================================================
resource "aws_customer_gateway" "gcp_cgw" {
  bgp_asn    = var.bgp_asn
  ip_address = var.on_prem_public_ip
  type       = "ipsec.1"
  tags       = { Name = "GCP-VPN-Gateway" }
}

resource "aws_vpn_connection" "tgw_vpn" {
  customer_gateway_id = aws_customer_gateway.gcp_cgw.id
  transit_gateway_id  = var.tgw_id
  type                = "ipsec.1"
  static_routes_only  = var.use_static_routing
  tags                = { Name = "S2S-GCP-Tunnel" }
}

# ==============================================================================
# SECTION 6: ROUTING LOGIC (The Traffic Brain)
# ==============================================================================

# 6a. VPC Route Table: All egress goes to GWLB Endpoints first
resource "aws_route" "vpc_to_gwlbe" {
  count                  = length(module.new_vpc.private_route_table_ids)
  route_table_id         = module.new_vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb_endpoints[count.index].id
}

# 6b. Snowflake Return Path (Snowflake RT -> Our VPC)
resource "aws_ec2_transit_gateway_route" "snowflake_to_vpc" {
  destination_cidr_block         = var.vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.snowflake_tgw_rt_id
}

# 6c. GCP/On-Prem Return Path (On-Prem RT -> Our VPC)
resource "aws_ec2_transit_gateway_route" "on_prem_to_vpc" {
  destination_cidr_block         = var.vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.on_prem_tgw_rt_id
}

# 6d. Forward Path to GCP VPN (Workload RT -> GCP VPN)
resource "aws_ec2_transit_gateway_route" "workload_to_gcp" {
  destination_cidr_block         = var.on_prem_internal_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.tgw_vpn.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.workload_tgw_rt_id
}

# ==============================================================================
# SECTION 7: GCP SIDE - THE OTHER HALF OF THE BRIDGE
# ==============================================================================

# 1. Create the HA VPN Gateway in GCP
resource "google_compute_ha_vpn_gateway" "gcp_gateway" {
  name    = "gcp-aws-ha-vpn"
  network = "default" # ACTION: Replace with your GCP VPC Name
}

# 2. Define AWS as the Peer Gateway
resource "google_compute_external_vpn_gateway" "aws_peer" {
  name            = "aws-tgw-peer"
  redundancy_type = "TWO_IPS_REDUNDANCY"
  
  interface {
    id         = 0
    ip_address = aws_vpn_connection.tgw_vpn.tunnel1_address
  }
  interface {
    id         = 1
    ip_address = aws_vpn_connection.tgw_vpn.tunnel2_address
  }
}

# 3. Create the Cloud Router
resource "google_compute_router" "gcp_router" {
  name    = "gcp-aws-router"
  network = "default" # ACTION: Replace with your GCP VPC Name
  bgp {
    asn = var.bgp_asn # 65000
  }
}

# 4. VPN Tunnels
resource "google_compute_vpn_tunnel" "tunnel_1" {
  name                            = "aws-tunnel-1"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.aws_peer.id
  peer_external_gateway_interface = 0
  shared_secret                   = aws_vpn_connection.tgw_vpn.tunnel1_preshared_key
  router                          = google_compute_router.gcp_router.id
  vpn_gateway_interface           = 0
}

resource "google_compute_vpn_tunnel" "tunnel_2" {
  name                            = "aws-tunnel-2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.gcp_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.aws_peer.id
  peer_external_gateway_interface = 1
  shared_secret                   = aws_vpn_connection.tgw_vpn.tunnel2_preshared_key
  router                          = google_compute_router.gcp_router.id
  vpn_gateway_interface           = 1
}

# 5. BGP Interfaces (The IP Handshake)
resource "google_compute_router_interface" "if_1" {
  name       = "if-aws-tunnel-1"
  router     = google_compute_router.gcp_router.name
  ip_range   = "${aws_vpn_connection.tgw_vpn.tunnel1_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_1.name
}

resource "google_compute_router_peer" "peer_1" {
  name            = "peer-aws-tunnel-1"
  router          = google_compute_router.gcp_router.name
  peer_ip_address = aws_vpn_connection.tgw_vpn.tunnel1_vgw_inside_address
  peer_asn        = 64512
  interface       = google_compute_router_interface.if_1.name
}

resource "google_compute_router_interface" "if_2" {
  name       = "if-aws-tunnel-2"
  router     = google_compute_router.gcp_router.name
  ip_range   = "${aws_vpn_connection.tgw_vpn.tunnel2_cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_2.name
}

resource "google_compute_router_peer" "peer_2" {
  name            = "peer-aws-tunnel-2"
  router          = google_compute_router.gcp_router.name
  peer_ip_address = aws_vpn_connection.tgw_vpn.tunnel2_vgw_inside_address
  peer_asn        = 64512
  interface       = google_compute_router_interface.if_2.name
}