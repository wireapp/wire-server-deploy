[all]
${connection_strings_node}
${connection_strings_etcd}
${connection_strings_minio}
${connection_strings_elasticsearch}
${connection_strings_cassandra}
${connection_strings_redis}
${connection_strings_restund}

[vpn:children]
k8s-cluster
minio
cassandra
elasticsearch
redis

[kube-master]
${list_master}

[kube-node]
${list_node}

# must be an odd number of servers! (playbooks will fail otherwise)
# See https://coreos.com/etcd/docs/latest/v2/admin_guide.html#optimal-cluster-size
[etcd]
${list_etcd}

[k8s-cluster:children]
kube-node
kube-master

[cassandra_seed]
cassandra0
cassandra1

[cassandra]
${list_cassandra}

[elasticsearch]
${list_elasticsearch}

[elasticsearch_master:children]
elasticsearch

[cassandra:vars]
is_aws_environment = False
# cassandra_clustername = default

[minio]
${list_minio}

[redis]
${list_redis}

[restund]
${list_restund}

[all:vars]
## path to the ssh private key
# ansible_ssh_private_key_file =

ansible_user = "root"

## use this when using python3 on the target machines
ansible_python_interpreter = /usr/bin/python3

## when you do not use ssh keys, enter the passwords to ssh and to become root
# ansible_ssh_pass = ...
# ansible_become_pass = ...

## set your desired network interfaces:
# minio_network_interface = vpn0
# elasticsearch_network_interface = vpn0
# cassandra_network_interface = vpn0
# redis_network_interface = vpn0
# registry_network_interface = vpn0

### KUBERNETES (see kubespray documentation for details) ###

bootstrap_os = ubuntu
## set this to false when you have more than 3 nameservers (required on e.g. Hetzner servers)
docker_dns_servers_strict = False

[k8s-cluster:vars]
helm_enabled = True
# flannel is preferred on bare-metal setups, in case you wish to use metallb
kube_network_plugin = flannel
## download the kubeconfig after installing to localhost
kubeconfig_localhost = True
