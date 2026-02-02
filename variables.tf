# --- VPC Configuration ---
variable "vpc_name" {
  type    = string
  default = "workload-vpc-01"
}

variable "vpc_cidr" {
  type    = string
  default = "10.50.64.0/22" # Updated per Cloud Team requirement
}

variable "azs" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
}

# --- Transit Gateway Infrastructure ---
variable "tgw_id" {
  type    = string
  default = "tgw-0473c470df70bb9bf" # Confirmed from AWS console
}

variable "workload_tgw_rt_id" {
  type        = string
  description = "The central TGW Route Table used for workload associations"
  default     = "tgw-rtb-0b5b3697be6faf893" # Association route table ID
}

variable "snowflake_tgw_rt_id" {
  type    = string
  default = "tgw-rtb-0687a78298c31688b" # ID for Snowflake return path
}

variable "on_prem_tgw_rt_id" {
  type    = string
  default = "tgw-rtb-0f3acdfcb74eac6f6" # Propagation route table ID
}

# --- Security VPC / GWLB Service ---
variable "gwlb_service_name" {
  type        = string
  description = "The Endpoint Service Name for the Fortinet firewalls"
  default     = "com.amazonaws.vpce.us-west-2.vpce-svc-xxxxxx" # ACTION: Replace with the actual service name from the Security team
}

# --- GCP Configuration ---
variable "on_prem_public_ip" {
  type    = string
  default = "34.124.9.4" # Interface 0 from your GCP VPN Gateway
}

variable "on_prem_internal_cidr" {
  type    = string
  default = "10.70.0.0/24" # Primary IPv4 range from GCP subnet
}

variable "use_static_routing" {
  type    = bool
  default = false # Set to false to support BGP dynamic routing for the HA VPN
}

variable "bgp_asn" {
  type    = number
  default = 65000 # Standard BGP ASN for GCP Cloud Routers
}