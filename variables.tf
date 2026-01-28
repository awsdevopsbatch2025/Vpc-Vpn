# --- VPC Configuration ---
variable "vpc_name" {
  type        = string
  description = "The name tag for the new workload VPC"
  default     = "new-workload-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the new VPC"
  default     = "10.80.0.0/22"
}

variable "azs" {
  type        = list(string)
  description = "The 4 Availability Zones to be used in us-west-2"
  default     = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
}

# --- Transit Gateway Infrastructure ---
variable "tgw_id" {
  type        = string
  description = "The ID of the existing central Transit Gateway"
  default     = "tgw-0473c470df70bb9bf"
}

variable "snowflake_tgw_rt_id" {
  type        = string
  description = "The Route Table ID for Snowflake traffic in the TGW"
  default     = "tgw-rtb-0687a78298c31688b"
}

variable "on_prem_tgw_rt_id" {
  type        = string
  description = "The Route Table ID for On-Prem/DCG traffic in the TGW"
  default     = "tgw-rtb-0f3acdfcb74eac6f6"
}

# --- GCP / Site-to-Site VPN Configuration ---
variable "on_prem_public_ip" {
  type        = string
  description = "The public IP of GCP HA VPN Interface 0"
  default     = "34.124.9.4" # Taken from your GCP screenshot
}

variable "on_prem_public_ip_secondary" {
  type        = string
  description = "The public IP of GCP HA VPN Interface 1"
  default     = "34.104.75.247" # Taken from your GCP screenshot
}

variable "on_prem_internal_cidr" {
  type        = string
  description = "The internal CIDR range of the GCP network (Gemini-NP)"
  default     = "10.128.0.0/9" # Standard GCP global range; adjust if your VPC is restricted
}

variable "use_static_routing" {
  type        = bool
  description = "Set to false for GCP BGP Dynamic routing"
  default     = false # Changed to false to support BGP as per POC design
}

variable "bgp_asn" {
  type        = number
  description = "The BGP ASN for the GCP side"
  default     = 65000 # Verify with Cloud team if GCP uses 16550
}