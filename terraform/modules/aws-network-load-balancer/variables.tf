variable "environment" {
  type        = string
  description = "name of the environment as a scope for the created resources (default: 'dev'; example: 'prod', 'staging')"
  default     = "dev"
}

variable "http_target_port" {
  type = number
  description = "HTTP port from the target machines that the LB forwards ingress on port 80 to"
  default = 8080
}

variable "https_target_port" {
  type = number
  description = "HTTPS port from the target machines that the LB forwards ingress on port 443 to"
  default = 8443
}

variable "target_role" {
  type = string
  description = ""
}