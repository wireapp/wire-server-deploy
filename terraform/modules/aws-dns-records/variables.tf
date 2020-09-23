variable "environment" {
  type        = string
  description = "name of the environment as a scope for the created resources (default: 'dev'; example: 'prod', 'staging')"
  default     = "dev"
}

variable "zone_fqdn" {
  type        = string
  description = "FQDN of the DNS zone root (required; example: example.com; will append: '.')"
}

variable "domain" {
  type        = string
  description = "name of the sub-tree all given subdomains are append to (defaults to $environment; example: $subdomains[0].$domain.$zone_fqdn)"
  default     = null
}

variable "subdomains" {
  type        = list(string)
  description = "list of sub-domains that will be registered under the given root domain"
  default = [
    "nginz-https",
    "nginz-ssl",
    "webapp",
    "assets",
    "account",
    "teams"
  ]
}

variable "inject_addition_subtree" {
  type        = bool
  description = "flag to indicate whether an additional level of depth based on environment name is injected into the DNS tree (e.g. webapp.dev.example.com vs. webapp.example.com"
  default     = true
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

variable "create_spf_record" {
  type    = bool
  default = false
}
