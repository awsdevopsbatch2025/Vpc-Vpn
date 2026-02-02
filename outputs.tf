# ==============================================================================
# SECTION 1: AWS INFRASTRUCTURE OUTPUTS
# ==============================================================================
output "aws_vpc_id" {
  description = "The ID of the newly created Workload VPC"
  value       = module.new_vpc.vpc_id
}

output "aws_gwlb_endpoint_ids" {
  description = "The IDs of the Gateway Load Balancer Endpoints for verification"
  value       = aws_vpc_endpoint.gwlb_endpoints[*].id
}

# ==============================================================================
# SECTION 2: GCP INFRASTRUCTURE OUTPUTS
# ==============================================================================
output "gcp_ha_vpn_gateway_ip_0" {
  description = "The first public IP of the GCP HA VPN Gateway"
  value       = google_compute_ha_vpn_gateway.gcp_gateway.vpn_interfaces[0].ip_address
}

output "gcp_ha_vpn_gateway_ip_1" {
  description = "The second public IP of the GCP HA VPN Gateway"
  value       = google_compute_ha_vpn_gateway.gcp_gateway.vpn_interfaces[1].ip_address
}

# ==============================================================================
# SECTION 3: VPN & TUNNEL DETAILS (SENSITIVE)
# ==============================================================================
output "vpn_tunnel1_address" {
  description = "The public IP address of the first AWS VPN tunnel"
  value       = aws_vpn_connection.tgw_vpn.tunnel1_address
}

output "vpn_tunnel2_address" {
  description = "The public IP address of the second AWS VPN tunnel"
  value       = aws_vpn_connection.tgw_vpn.tunnel2_address
}

output "vpn_preshared_keys" {
  description = "The shared secrets for the VPN tunnels"
  value = {
    tunnel_1 = aws_vpn_connection.tgw_vpn.tunnel1_preshared_key
    tunnel_2 = aws_vpn_connection.tgw_vpn.tunnel2_preshared_key
  }
  sensitive = true
}

# ==============================================================================
# SECTION 4: ONE-CLICK VERIFICATION COMMANDS
# ==============================================================================
output "verify_gcp_tunnels_command" {
  description = "Run this command in your terminal to check the status of your GCP tunnels"
  value       = "gcloud compute vpn-tunnels list --project=${var.gcp_project_id} --region=${var.gcp_region}"
}

output "verify_bgp_sessions_command" {
  description = "Run this command to see if the BGP handshake is successful"
  value       = "gcloud compute routers get-status ${google_compute_router.gcp_router.name} --region=${var.gcp_region} --project=${var.gcp_project_id}"
}