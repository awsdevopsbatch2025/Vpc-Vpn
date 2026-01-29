# --- VPC Configuration ---
variable "vpc_name" {
  type    = string
  default = "workload-vpc-01"
}

variable "vpc_cidr" {
  type    = string
  default = "10.80.0.0/22"
}

variable "azs" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
}

# --- Transit Gateway Infrastructure ---
variable "tgw_id" {
  type    = string
  default = "tgw-0473c470df70bb9bf"
}

variable "workload_tgw_rt_id" {
  type        = string
  description = "The central TGW Route Table used for workload associations"
  default     = "tgw-rtb-xxxxxx" # ACTION: Get this from AWS console
}

variable "snowflake_tgw_rt_id" {
  type    = string
  default = "tgw-rtb-0687a78298c31688b"
}

variable "on_prem_tgw_rt_id" {
  type    = string
  default = "tgw-rtb-0f3acdfcb74eac6f6"
}

# --- Security VPC / GWLB Service ---
variable "gwlb_service_name" {
  type        = string
  description = "The Endpoint Service Name for the Fortinet firewalls"
  default     = "com.amazonaws.vpce.us-west-2.vpce-svc-xxxxxx" # ACTION: Get from Security team
}

# --- GCP Configuration ---
variable "on_prem_public_ip" {
  type    = string
  default = "34.124.9.4" # Interface 0 from your GCP screenshot
}

variable "on_prem_internal_cidr" {
  type    = string
  default = "10.128.0.0/9" # GCP VPC range
}

variable "use_static_routing" {
  type    = bool
  default = false # Set to false to support BGP for GCP HA VPN
}

variable "bgp_asn" {
  type    = number
  default = 65000
}