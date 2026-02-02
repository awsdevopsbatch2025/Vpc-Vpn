# ==============================================================================
# OUTPUTS FOR GCP CONFIGURATION
# Use these values to complete the Peer VPN Gateway setup in Google Cloud.
# ==============================================================================

output "vpc_id" {
  description = "The ID of the newly created Workload VPC"
  value       = module.new_vpc.vpc_id
}

output "gwlb_endpoint_ids" {
  description = "The IDs of the Gateway Load Balancer Endpoints for verification"
  value       = aws_vpc_endpoint.gwlb_endpoints[*].id
}

output "vpn_tunnel1_address" {
  description = "The public IP address of the first AWS VPN tunnel"
  value       = aws_vpn_connection.tgw_vpn.tunnel1_address
}

output "vpn_tunnel1_preshared_key" {
  description = "The secret key for the first AWS VPN tunnel (Use in GCP Peer VPN setup)"
  value       = aws_vpn_connection.tgw_vpn.tunnel1_preshared_key
  sensitive   = true
}

output "vpn_tunnel2_address" {
  description = "The public IP address of the second AWS VPN tunnel"
  value       = aws_vpn_connection.tgw_vpn.tunnel2_address
}

output "vpn_tunnel2_preshared_key" {
  description = "The secret key for the second AWS VPN tunnel (Use in GCP Peer VPN setup)"
  value       = aws_vpn_connection.tgw_vpn.tunnel2_preshared_key
  sensitive   = true
}

output "aws_bgp_asn" {
  description = "The BGP ASN of the AWS Transit Gateway side"
  value       = 64512 # Confirmed from your AWS Console screenshot
}