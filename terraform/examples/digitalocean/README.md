# Digitalocean example

Used this as a quick playground as I was more familiar with DO API than hetzner

set `DIGITALOCEAN_TOKEN` in `.envrc.local`:
```
# .envrc.local
export DIGITALOCEAN_TOKEN=......
```

Provision resources:
```
$ terraform apply
```


Set `TF_STATE` so that `terraform-inventory.sh` can find the terraform state:
```
$ export TF_STATE=$(pwd)/terraform.tfstate
```

Run the playbook to bootstrap the cluster:
```
$ cd  ../../ansible
$ ansible-playbook -i ./inventory/offline/terraform-inventory.sh cluster.yml
```

