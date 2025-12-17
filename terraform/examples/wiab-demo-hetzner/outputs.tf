output "ssh_private_key" {
  sensitive = true
  value = tls_private_key.host.private_key_pem
}

output "selected_server_types" {
  description = "Server types selected after checking availability"
  value = {
    server_type = local.server_type
  }
}

output "host" {
  sensitive = true
  value = hcloud_server.host.ipv4_address
}
