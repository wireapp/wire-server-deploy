environment = "CHANGE_ME:generic-name"

root_domain = "CHANGE_ME:FQDN"
# NOTE: corresponds to helm_vars/[wire-server,nginx-ingress-services]/values.yaml
sub_domains = [
  "nginz-https",
  "nginz-ssl",
  "webapp",
  "assets",
  "account",
  "teams"
]
create_spf_record = true

operator_ssh_public_keys = {
  terraform_managed = {
    "CHANGE_ME:unique-name" = "CHANGE_ME:key-file-content"
  }
  preuploaded_key_names = []
}

k8s_cluster = {
  cloud = "hetzner"

  # NOTE: corresponds to wire-server/charts/ingress-nginx-controller/values.yaml#nodePorts
  load_balancer_ports = [
    {
      name = "http"
      protocol = "tcp"
      listen = 80
      destination = 31772
    },
    {
      name = "https"
      protocol = "tcp"
      listen = 443
      destination = 31773
    }
  ]

  machine_groups = [
    {
      group_name = "cps"
      machine_count = 1
      machine_type = "cx21"
      component_classes = [ "controlplane" ]
    },

    {
      group_name = "nodes"
      machine_count = 2
      machine_type = "cpx41"
      component_classes = [ "node" ]
    },
  ]
}
