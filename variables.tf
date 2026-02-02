# ==============================================================================
# SECTION 1: AWS VPC & INFRASTRUCTURE
# ==============================================================================
variable "vpc_name" {
  type    = string
  default = "workload-vpc-01"
}

variable "vpc_cidr" {
  type    = string
  default = "10.50.64.0/22"
}

variable "azs" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
}

# ==============================================================================
# SECTION 2: TRANSIT GATEWAY (TGW) IDs
# ==============================================================================
variable "tgw_id" {
  type    = string
  default = "tgw-0473c470df70bb9bf"
}

variable "workload_tgw_rt_id" {
  type        = string
  description = "The central TGW Route Table used for workload associations"
  default     = "tgw-rtb-0b5b3697be6faf893"
}

variable "snowflake_tgw_rt_id" {
  type    = string
  default = "tgw-rtb-0687a78298c31688b"
}

variable "on_prem_tgw_rt_id" {
  type    = string
  default = "tgw-rtb-0f3acdfcb74eac6f6"
}

# ==============================================================================
# SECTION 3: SECURITY & FIREWALL
# ==============================================================================
variable "gwlb_service_name" {
  type        = string
  description = "The Endpoint Service Name for the Fortinet firewalls"
  default     = "com.amazonaws.vpce.us-west-2.vpce-svc-xxxxxx" 
}

# ==============================================================================
# SECTION 4: GCP PROJECT & NETWORK (NEW)
# ==============================================================================
variable "gcp_project_id" {
  type        = string
  description = "The Google Cloud Project ID where the VPN will be built"
  default     = "credit-one-gcp-project-01" # ACTION: Update with your real Project ID
}

variable "gcp_vpc_name" {
  type        = string
  description = "The name of the existing VPC network in GCP"
  default     = "default" # ACTION: Update with your GCP VPC name
}

variable "gcp_region" {
  type        = string
  default     = "us-west1"
}

# ==============================================================================
# SECTION 5: HYBRID CONNECTIVITY (VPN & BGP)
# ==============================================================================
variable "on_prem_public_ip" {
  type    = string
  default = "34.124.9.4" # This is the public IP of your GCP HA VPN
}

variable "on_prem_internal_cidr" {
  type    = string
  default = "10.70.0.0/24" # The subnet inside GCP we want to reach
}

variable "use_static_routing" {
  type    = bool
  default = false # Must be false for HA VPN BGP sessions
}

variable "bgp_asn" {
  type    = number
  default = 65000 # The ASN for the GCP side
}