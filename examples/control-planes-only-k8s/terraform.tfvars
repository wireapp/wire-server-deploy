environment = "CHANGE_ME:generic-name"

root_domain = "CHANGE_ME:FQDN"

operator_ssh_public_keys = {
  terraform_managed = {
    "CHANGE_ME:unique-name" = "CHANGE_ME:key-file-content"
  }
  preuploaded_key_names = []
}

k8s_cluster = {
  cloud = "hetzner"

  machine_groups = [
    {
      group_name = "cpns"
      # NOTE: set to 1 in order to get a single-machine Kubernetes cluster
      machine_count = 3
      machine_type = "cx21"
      component_classes = [ "controlplane", "node" ]
    }
  ]
}
