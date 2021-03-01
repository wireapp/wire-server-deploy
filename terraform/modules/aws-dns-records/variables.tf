variable "zone_fqdn" {
  type        = string
  description = "FQDN of the DNS zone root (required; example: example.com; will append: '.')"
}

variable "domain" {
  type        = string
  description = "name of the sub-tree all given subdomains are append to (default: not set; example: $subdomains[0].$domain.$zone_fqdn)"
  default     = null
}

variable "subdomains" {
  type        = list(string)
  description = "list of sub-domains that will be registered directly under the given zone or otherwise under domain if defined"
}

variable "ips" {
  type        = list(string)
  description = "a list of IPs used to create A records for the given list of subdomains"
  default     = []
}

variable "cnames" {
  type        = list(string)
  description = "a list of FQDNs used to create CNAME records for the given list of subdomains"
  default     = []
}

variable "ttl" {
  type        = number
  description = "time to live for the DNS entries (defaults to 1 minute)"
  default     = 60
}

variable "spf_record_ips" {
  type        = list(string)
  description = "list of IPs converted into a list of 'ip4' mechanisms"
  default     = []
}

variable "srvs" {
  type        = map(list(string))
  description = "map of SRV records and their list of targets. All strings (record and targets) get an automatic suffix of '.domain.zone_fqdn'. See module README for an example."
  default     = {}
}
