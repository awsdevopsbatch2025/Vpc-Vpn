# ==============================================================================
# SECTION 1: VPC INFRASTRUCTURE (4 AZs)
# ==============================================================================
module "new_vpc" {
  source  = "app.terraform.io/creditonebank/vpc-module/aws"
  version = "1.1.7"

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets  = ["10.80.0.0/24", "10.80.1.0/24", "10.80.2.0/24", "10.80.3.0/24"]
  firewall_subnets = ["10.80.3.192/28", "10.80.3.208/28", "10.80.3.224/28", "10.80.3.240/28"]
}

# ==============================================================================
# SECTION 2: SECURITY VPC INSPECTION (GWLB Endpoints)
# Fixed: Using subnet_ids as a list to resolve Terraform validation error.
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
  appliance_mode_support = "enable"

  tags = { Name = "tgw-attach-new-workload" }
}

resource "aws_ec2_transit_gateway_route_table_association" "workload_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.workload_tgw_rt_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "workload_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.workload_tgw_rt_id
}

# ==============================================================================
# SECTION 4: SECURITY GROUPS
# ==============================================================================
resource "aws_security_group" "workload_sg" {
  name        = "workload-internal-sg"
  description = "Allows traffic from internal bank network and GCP"
  vpc_id      = module.new_vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", var.on_prem_internal_cidr]
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
  ip_address = var.on_prem_public_ip # From GCP Screenshot: 34.124.9.4
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

# 6a. VPC Route Table: Send all egress (0.0.0.0/0) to GWLB Endpoints first
resource "aws_route" "vpc_to_gwlbe" {
  count                  = length(module.new_vpc.private_route_table_ids)
  route_table_id         = module.new_vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb_endpoints[count.index].id
}

# 6b. Snowflake Return Path
resource "aws_ec2_transit_gateway_route" "snowflake_to_vpc" {
  destination_cidr_block         = var.vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.snowflake_tgw_rt_id
}

# 6c. GCP Return Path
resource "aws_ec2_transit_gateway_route" "on_prem_to_vpc" {
  destination_cidr_block         = var.vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.on_prem_tgw_rt_id
}