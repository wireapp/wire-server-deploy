output "ssh_private_key" {
  sensitive = true
  value     = tls_private_key.host.private_key_pem
}

output "selected_server_types" {
  description = "Server types selected for the current deployment attempt"
  value = {
    server_type = var.server_type
  }
}

output "selected_location" {
  description = "Location selected for the current deployment attempt"
  value       = var.location
}

output "resource_fallback_info" {
  description = "Information about the requested deployment combination and its availability"
  value = {
    requested_location     = var.location
    selected_location      = var.location
    requested_server_type  = var.server_type
    selected_server_type   = var.server_type
    available_locations    = local.available_location_names
    available_server_types = local.available_server_type_names
  }
}

output "host" {
  sensitive = true
  value     = hcloud_server.host.ipv4_address
}
