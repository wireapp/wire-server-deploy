environment = "CHANGE_ME:generic-name"

root_domain = "CHANGE_ME:FQDN"

operator_ssh_public_keys = {
  terraform_managed = {
    "CHANGE_ME:unique-name" = "CHANGE_ME:key-file-content"
  }
  preuploaded_key_names = []
}

sft_server_names_blue  = ["1", "2", "3"]
sft_server_type_blue   = "cx31"
sft_server_names_green = ["4", "5", "6"]
sft_server_type_green  = "cx31"
