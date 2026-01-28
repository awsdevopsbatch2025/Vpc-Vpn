# ==============================================================================
# SECTION 1: VPC INFRASTRUCTURE (4 AZs)
# Creates the networking foundation in us-west-2 using the bank's module.
# ==============================================================================
module "new_vpc" {
  source  = "app.terraform.io/creditonebank/vpc-module/aws"
  version = "1.1.7"

  name = "workload-vpc-01"
  cidr = var.vpc_cidr
  azs  = var.azs

  # Private subnets for workloads and Firewall subnets for TGW/ENI endpoints
  private_subnets  = ["10.80.0.0/24", "10.80.1.0/24", "10.80.2.0/24", "10.80.3.0/24"]
  firewall_subnets = ["10.80.3.192/28", "10.80.3.208/28", "10.80.3.224/28", "10.80.3.240/28"]
}

# ==============================================================================
# SECTION 2: TRANSIT GATEWAY (TGW) CONNECTION
# Plugs the VPC into the central TGW hub with "Appliance Mode" for GLB/Firewalls.
# ==============================================================================
resource "aws_ec2_transit_gateway_vpc_attachment" "workload_attachment" {
  subnet_ids         = module.new_vpc.private_subnets
  transit_gateway_id = var.tgw_id
  vpc_id             = module.new_vpc.vpc_id

  # CRITICAL: Ensures return traffic hits the same AZ firewall in the Security VPC
  appliance_mode_support = "enable"

  tags = { Name = "tgw-attach-new-workload" }
}

# ==============================================================================
# SECTION 3: SECURITY GROUPS (Micro-Segmentation)
# The local firewall for your app instances.
# ==============================================================================
resource "aws_security_group" "workload_sg" {
  name        = "workload-internal-sg"
  description = "Allows traffic from internal bank network"
  vpc_id      = module.new_vpc.vpc_id

  # Inbound: Allow all internal traffic (adjustable to specific ports if needed)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", var.on_prem_internal_cidr]
  }

  # Outbound: Allow everything
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# SECTION 4: SITE-TO-SITE VPN
# Connects the on-prem router to the AWS Transit Gateway.
# ==============================================================================
resource "aws_customer_gateway" "on_prem_cgw" {
  bgp_asn    = var.bgp_asn
  ip_address = var.on_prem_public_ip
  type       = "ipsec.1"
  tags       = { Name = "On-Prem-Router" }
}

resource "aws_vpn_connection" "tgw_vpn" {
  customer_gateway_id = aws_customer_gateway.on_prem_cgw.id
  transit_gateway_id  = var.tgw_id
  type                = "ipsec.1"
  static_routes_only  = var.use_static_routing
  tags                = { Name = "S2S-VPN-Tunnel" }
}

# ==============================================================================
# SECTION 5: ROUTING (THE "TRAFFIC BRAIN")
# Connects the New VPC to the Security VPC, Snowflake, and On-Prem.
# ==============================================================================

# 5a. Outbound from VPC: Send all internal/internet traffic to TGW
resource "aws_route" "vpc_to_tgw" {
  count                  = length(module.new_vpc.private_route_table_ids)
  route_table_id         = module.new_vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0" 
  transit_gateway_id     = var.tgw_id
}

# 5b. Snowflake Return Path: Tell Snowflake RT how to find the New VPC
resource "aws_ec2_transit_gateway_route" "snowflake_to_vpc" {
  destination_cidr_block         = var.vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.snowflake_tgw_rt_id
}

# 5c. On-Prem Return Path: Tell On-Prem (DCG) RT how to find the New VPC
resource "aws_ec2_transit_gateway_route" "on_prem_to_vpc" {
  destination_cidr_block         = var.vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_attachment.id
  transit_gateway_route_table_id = var.on_prem_tgw_rt_id
}
