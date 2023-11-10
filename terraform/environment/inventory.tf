# Generates an inventory file to be used by ansible. Ideally, we would generate
# this outside terraform using outputs, but it is not possible to use 'terraform
# output' when the init directory is different from the root code directory.
# Terraform Issue: https://github.com/hashicorp/terraform/issues/17300
output "inventory" {
  value = merge(
    local.sft_inventory,
    local.k8s_cluster_inventory
  )
  sensitive = true
}
