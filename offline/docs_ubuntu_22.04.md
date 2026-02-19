# How to install wire (offline cluster)

We have a pipeline in  `wire-server-deploy` producing container images, static
binaries, ansible playbooks, debian package sources and everything required to
install Wire.

## Demo / Testing installation

To install a self-hosted instance of Wire deployed on one Server ("Wire in a box") for testing purposes, we recommend the [WIAB Staging](wiab-staging.md) or [WIAB Dev](https://docs.wire.com/latest/how-to/install/demo-wiab.html) solution.

## Installing docker

Note: If you are using a Hetzner machine, docker should already be installed (you can check with `docker version`) and you can skip this section.

On your machine (we call this the "admin host"), you need to have `docker`
installed (or any other compatible container runtime really, even though
instructions may need to be modified). See [how to install
docker](https://docker.com) for instructions.

On ubuntu 22.04, connected to the internet:

```
sudo bash -c '
set -eo pipefail;

apt install docker.io;
systemctl enable docker;
systemctl start docker;
'
```

Ensure the user you are using for the install has permission to run docker, or add 'sudo' to the docker commands below.

### Ensuring you can run docker without sudo:

Run the following command to add your user to the docker group:

```
sudo usermod -aG docker $USER
```

Note: Replace $USER with your actual username as needed.

Log out and log back in to apply the changes. Alternatively, you can run the following command to activate the changes in your current shell session:

```
newgrp docker
```

Verify that you can run Docker without sudo by running the following command:

```
docker version
```

If you see the curent docker version and no error, it means that Docker is now configured to run without sudo.


## Downloading and extracting the artifact

Create a fresh workspace to download the artifacts:

```
$ cd ...  # you pick a good location!
```
Obtain the latest airgap artifact for wire-server-deploy. Please contact us to get it.

Extract the above listed artifacts into your workspace:

```
$ wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-<HASH>.tgz
$ tar xvzf wire-server-deploy-static-<HASH>.tgz
```
Where `<HASH>` above is the hash of your deployment artifact, given to you by Wire, or acquired by looking at the above build job.
Extract this tarball.

Make sure that the admin host can `ssh` into all the machines that you want to provision. Our docker container will use the `.ssh` folder and the `ssh-agent` of the user running the scripts.

There's also a docker image containing the tooling inside this repo.

## Making tooling available in your environment.

If you don't intend to develop *on wire-server-deploy itself*, you should source the following shell script.
```
source ./bin/offline-env.sh
```

The shell script will set up a `d` alias. Which runs commands passed to it inside the docker container
with all the tools needed for doing an offline deploy.

E.g.:

```
$ d ansible --version
ansible [core 2.15.5]
  config file = /wire-server-deploy/ansible/ansible.cfg
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /nix/store/p9kbf1v35r184hwx9p4snny1clkbrvp7-python3.11-ansible-core-2.15.5/lib/python3.11/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /nix/store/p9kbf1v35r184hwx9p4snny1clkbrvp7-python3.11-ansible-core-2.15.5/bin/ansible
  python version = 3.11.6 (main, Oct  2 2023, 13:45:54) [GCC 12.3.0] (/nix/store/qp5zys77biz7imbk6yy85q5pdv7qk84j-python3-3.11.6/bin/python3.11)
  jinja version = 3.1.2
  libyaml = True


```

## Artifacts provided in the deployment tarball.

The following artifacts are provided:

 - `containers-adminhost/wire-server-deploy-*.tar`
   A container image containing ansible, helm, and other tools and their
   dependencies in versions verified to be compatible with the current wire
   stack. Published to `quay.io/wire/wire-server-deploy` as well, but shipped
   in the artifacts tarball for convenience.
 - `ansible`
   These contain all the ansible playbooks the rest of the guide refers to, as
   well as an example inventory, which should be configured according to the
   environment this is installed into.
 - `binaries.tar`
   This contains static binaries, both used during the kubespray-based
   kubernetes bootstrapping, as well as to provide some binaries that are
   installed during other ansible playbook runs.
 - `charts`
   The charts themselves, as tarballs. We don't use an external helm
   repository, every helm chart dependency is resolved already.
 - `containers-system.tar`
   These are the container images needed to bootstrap kubernetes itself
   (currently using kubespray)
 - `containers-helm.tar`
   These are the container images our charts (and charts we depend on) refer to.
   Also come as tarballs, and are seeded like the system containers.
 - `debs-jammy.tar`
   This acts as a self-contained dump of all packages required to install
   kubespray, as well as all other packages that are installed by ansible
   playbooks on nodes that don't run kubernetes.
   There's an ansible playbook copying these assets to an "assethost", starting
   a little webserver there serving it, and configuring all nodes to use it as
   a package repo.
 - `values`
   Contains helm chart values and secrets. Needs to be tweaked to the
   environment.

## Editing the inventory

Copy `ansible/inventory/offline/99-static`  to `ansible/inventory/offline/hosts.ini`, and remove the original.

```
cp ansible/inventory/offline/99-static ansible/inventory/offline/hosts.ini
mv ansible/inventory/offline/99-static ansible/inventory/offline/orig.99-static
```

Edit `ansible/inventory/offline/hosts.ini`.
Here, you will describe the topology of your offline deploy.  There's instructions in the comments on how to set
everything up. You can also refer to extra information here. https://docs.wire.com/how-to/install/ansible-VMs.html

Add one entry in the `all` section of this file for each machine you are managing via ansible. This will be all of the machines in your Wire cluster.

If you are using username/password to log into and sudo up, in the `all:vars` section, add:
```
ansible_user=<USERNAME>
ansible_password=<PASSWORD>
ansible_become_pass=<PASSWORD>
```
#### Editing the ansible inventory

##### Updating Group Membership
It's recommended to update the lists of what nodes belong to which group, so ansible knows what to install on these nodes.

For our Wire internal offline deployments using seven VMs, we edit the inventory to run all services outside of K8s on three `ansnode` VMs.
For productive on-prem deployments, these sections can be divided into individual host groups, reflecting the architecture of the target infrastructure.
Examples with individual nodes for Elastic, MinIO, and Cassandra are commented out below.
```
[elasticsearch]
# elasticsearch1
# elasticsearch2
# elasticsearch3
ansnode1
ansnode2
ansnode3

[minio]
# minio1
# minio2
# minio3
ansnode1
ansnode2
ansnode3

[cassandra]
# cassandra1
# cassandra2
# cassandra3
ansnode1
ansnode2
ansnode3

[cassandra_seed]
# cassandraseed1
ansnode1

```

### Configuring kubernetes and etcd

To run Kubernetes, at least three nodes are required, which need to be added to the `[kube-master]`, `[etcd]`  and `[kube-node]` groups of the inventory file. Any
additional nodes should only be added to the `[kube-node]` group:
For our Wire internal offline deployments using seven VMs, we edit the inventory to run all services inside K8s on three `kubenode` VMs.
For productive on-prem deployments, these sections can be divided into individual host groups, reflecting the architecture of the target infrastructure.
```
[kube-master]
# kubemaster1
# kubemaster2
# kubemaster3
kubenode1
kubenode2
kubenode3

[etcd]
# etcd1 etcd_member_name=etcd1
# etcd2 etcd_member_name=etcd2
# etcd3 etcd_member_name=etcd3
kubenode1 etcd_member_name=etcd1
kubenode2 etcd_member_name=etcd2
kubenode3 etcd_member_name=etcd3

[kube-node]
# prodnode1
# prodnode2
# prodnode3
# prodnode4
# ...
kubenode1
kubenode2
kubenode3
```

### Setting up databases and kubernetes to talk over the correct (private) interface
If you are deploying wire on servers that are expected to use one interface to talk to the public, and a separate interface to talk amongst themselves, you will need to add "ip=" declarations for the private interface of each node. for instance, if the first kubenode was expected to talk to the world on 192.168.122.21, but speak to other wire services (kubernetes, databases, etc) on 192.168.0.2, you should edit its entry like the following:
```
kubenode1 ansible_host=192.168.122.21 ip=192.168.0.2
```
Do this for all of the instances.

### Setting up Database network interfaces.
* Make sure that `assethost` is present in the inventory file with the correct `ansible_host` (and `ip` values if required)
* Make sure that `cassandra_network_interface` is set to the name of the network interface on which the kubenodes should talk to cassandra and on which the cassandra nodes
  should communicate among each other. Run `ip addr` on one of the cassandra nodes to determine the network interface names, and which networks they correspond to. In Ubuntu 22.04 for example, interface names are predictable and individualized, eg. `enp41s0`.
* Similarly `elasticsearch_network_interface` and `minio_network_interface` should be set to the network interface names you want elasticsearch and minio to communicate with kubernetes with, as well.


### Marking kubenode for calling server (SFT)

The SFT Calling server should be running on a kubernetes nodes that are connected to the public internet.
If not all kubernetes nodes match these criteria, you should specifically label the nodes that do match
these criteria, so that you're sure SFT is deployed correctly.


By using a `node_label` you can make sure SFT is only deployed on a certain node like `kubenode4`

```
kubenode4 node_labels="{'wire.com/role': 'sftd'}" node_annotations="{'wire.com/external-ip': 'a.b.c.d'}"
```

If the node does not know its onw public IP (e.g. becuase it's behind NAT) then you should also set
the `wire.com/external-ip` annotation to the public IP of the node.

### Configuring MinIO

In order to automatically generate deeplinks, Edit the minio variables in `[minio:vars]` (`prefix`, `domain` and `deeplink_title`) by replacing `example.com` with your own domain.


### Example hosts.ini

Here is an example `hosts.ini` file for an internal "Wire in a box" deployment with seven VMs.
Please note that your on-prem infrastructure requirements likely differ in terms of number of VMs / nodes, IP addresses and ranges, as well as host names.

```
[all]
assethost ansible_host=192.168.122.10
kubenode1 ansible_host=192.168.122.21
kubenode2 ansible_host=192.168.122.22
kubenode3 ansible_host=192.168.122.23
ansnode1 ansible_host=192.168.122.31
ansnode2 ansible_host=192.168.122.32
ansnode3 ansible_host=192.168.122.33

[all:vars]
ansible_user = demo

[cassandra:vars]
cassandra_network_interface = enp1s0
cassandra_backup_enabled = False
cassandra_incremental_backup_enabled = False
# cassandra_backup_s3_bucket =

[elasticsearch:vars]
elasticsearch_network_interface = enp1s0

[minio:vars]
minio_network_interface = enp1s0
prefix = ""
domain = "example.com"
deeplink_title = "wire demo environment, example.com"

[rmq-cluster:vars]
rabbitmq_network_interface = enp1s0

[kube-master]
kubenode1
kubenode2
kubenode3

[etcd]
kubenode1 etcd_member_name=etcd1
kubenode2 etcd_member_name=etcd2
kubenode3 etcd_member_name=etcd3

[kube-node]
kubenode1
kubenode2
kubenode3

[k8s-cluster:children]
kube-master
kube-node

[cassandra]
ansnode1
ansnode2
ansnode3

[cassandra_seed]
ansnode1

[elasticsearch]
ansnode1
ansnode2
ansnode3

[elasticsearch_master:children]
elasticsearch

[minio]
ansnode1
ansnode2
ansnode3

[rmq-cluster]
ansnode1
ansnode2
ansnode3

```

## Generating secrets

Minio and coturn services have shared secrets with the `wire-server` helm chart. Run the folllowing script that generates a fresh set of secrets for these components:

```
./bin/offline-secrets.sh
```

This should generate two secret files.
- `./ansible/inventory/group_vars/all/secrets.yaml`
- `values/wire-server/secrets.yaml`


### WORKAROUND: old debian key
All of our debian archives up to version 4.12.0 used a now-outdated debian repository signature. Some modifications are required to be able to install everything properly.

Edit the ansible/setup-offline-sources.yml file

Open it with your prefered text editor and edit the following:
* find a big block of comments and uncomment everything in it `- name: trust anything...`
* after the block you will find `- name: Register offline repo key...`. Comment out that segment (do not comment out the part with `- name: Register offline repo`!)

Then disable checking for outdated signatures by editing the following file:
```
ansible/roles-external/kubespray/roles/container-engine/docker/tasks/main.yml
```
* comment out the block with -name: ensure docker-ce repository public key is installed...
* comment out the next block -name: ensure docker-ce repository is enabled

Now you are ready to start deploying services.

#### WORKAROUND: dependency

Some ubuntu systems do not have GPG by default. Wire assumes this is already present. Ensure you have gpg installed on all of your nodes before continuing to the next step.

You can check if gpg is installed by running:

```
gpg --version
```

Which should produce an output ressembling:

```
demo@assethost:~$ gpg --version
gpg (GnuPG) 2.2.27
libgcrypt 1.9.4
Copyright (C) 2021 Free Software Foundation, Inc.
License GNU GPL-3.0-or-later <https://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Home: /home/demo/.gnupg
Supported algorithms:
Pubkey: RSA, ELG, DSA, ECDH, ECDSA, EDDSA
Cipher: IDEA, 3DES, CAST5, BLOWFISH, AES, AES192, AES256, TWOFISH,
        CAMELLIA128, CAMELLIA192, CAMELLIA256
Hash: SHA1, RIPEMD160, SHA256, SHA384, SHA512, SHA224
Compression: Uncompressed, ZIP, ZLIB, BZIP2
```

## Deploying Kubernetes and stateful services

In order to deploy all mentioned services, run:
```
d ./bin/offline-cluster.sh
```
In case any of the steps in this script fail, see the notes in the comments that accompany each step.
Comment out steps that have already completed when re-running the scripts.

#### Ensuring Kubernetes is healthy.

Ensure the cluster comes up healthy. The container also contains `kubectl`, so check the node status:

```
d kubectl get nodes -owide
```
They should all report ready.

### Troubleshooting external services
Cassandra, Minio and Elasticsearch are running outside Kubernets cluster, make sure those machines have necessary ports open -

On each of the machines running Cassandra, Minio and Elasticsearch, run the following commands to open the necessary ports, if needed:
```
sudo bash -c '
set -eo pipefail;

# cassandra
ufw allow 9042/tcp;
ufw allow 9160/tcp;
ufw allow 7000/tcp;
ufw allow 7199/tcp;

# elasticsearch
ufw allow 9300/tcp;
ufw allow 9200/tcp;

# minio
ufw allow 9000/tcp;
ufw allow 9092/tcp;

#rabbitmq
ufw allow 5671/tcp;
ufw allow 5672/tcp;
ufw allow 4369/tcp;
ufw allow 25672/tcp;
'
```

### Deploy RabbitMQ cluster
Follow the steps mentioned here to create a RabbitMQ cluster based on your setup - [offline/rabbitmq_setup.md](./rabbitmq_setup.md)

### Preparation for Federation
For enabling Federation, we need to have RabbitMQ in place. Please follow the instructions in [offline/federation_preparation.md](./federation_preparation.md) for setting up RabbitMQ.

After that continue to the next steps below.

### Deploying Wire

It's now time to deploy the helm charts on top of kubernetes, installing the Wire platform.

#### Finding the stateful services
First, setup interfaces from Kubernetes to external services by running:

```
d helm install cassandra-external ./charts/cassandra-external --values ./values/cassandra-external/values.yaml
d helm install elasticsearch-external ./charts/elasticsearch-external --values ./values/elasticsearch-external/values.yaml
d helm install minio-external ./charts/minio-external --values ./values/minio-external/values.yaml
```

#### Deploying stateless dependencies

Also copy the values file for `databases-ephemeral` as it is required for the next step:

```
cp values/databases-ephemeral/prod-values.example.yaml values/databases-ephemeral/values.yaml
# edit values.yaml if necessary
d helm install databases-ephemeral ./charts/databases-ephemeral/ --values ./values/databases-ephemeral/values.yaml
```

Next, two more services will be deployed without additional configuration:
```
d helm install fake-aws ./charts/fake-aws --values ./values/fake-aws/prod-values.example.yaml

d helm install reaper ./charts/reaper
```

#### SMTP

For onboarding users via e-mail, update the configuration for `brig.config.smtp` with your SMTP. We also ship a `smtp` package with our bundle for demo/testing purposes, which is also possible to be used outside that scope, as an actual SMTP relay. For a generic setup, please read [docs.md](smtp.md) for more details.

For a temporary SMTP service:

### ensure that the RELAY_NETWORKS value is set to the podCIDR

```
SMTP_VALUES_FILE="./values/smtp/prod-values.example.yaml"
podCIDR=$(d kubectl get configmap -n kube-system kubeadm-config -o yaml | grep -i 'podSubnet' | awk '{print $2}' 2>/dev/null)
if [[ $? -eq 0 && -n "$podCIDR" ]]; then
  sed -i "s|RELAY_NETWORKS: \".*\"|RELAY_NETWORKS: \":${podCIDR}\"|" $SMTP_VALUES_FILE
else
    echo "Failed to fetch podSubnet. Attention using the default value: $(grep -i RELAY_NETWORKS $SMTP_VALUES_FILE)"
fi
d helm install smtp ./charts/smtp --values $SMTP_VALUES_FILE
```

#### Preparing your values

Next, move `./values/wire-server/prod-values.example.yaml` to `./values/wire-server/values.yaml`.

```
cp ./values/wire-server/prod-values.example.yaml ./values/wire-server/values.yaml
```

Inspect all the values and adjust domains to your domains where needed.

Add the IPs of your `coturn` servers to the `turnStatic.v2` list:
```yaml
  turnStatic:
    v1: []
    v2:
      - "turn:<IP of coturn1>:3478"
      - "turn:<IP of coturn2>:3478"
      - "turn:<IP of coturn1>:3478?transport=tcp"
      - "turn:<IP of coturn2>:3478?transport=tcp"
```

Open up `./values/wire-server/secrets.yaml` and inspect the values. In theory
this file should have only generated secrets, and no additional secrets have to
be added, unless additional options have been enabled.

Open up `./values/wire-server/values.yaml` and replace example.com and other domains and subdomain with your domain. You can do it with:

```
sed -i 's/example.com/<your-domain>/g' ./values/wire-server/values.yaml
```

#### [Optional] Using Kubernetes managed Cassandra (K8ssandra)
You can deploy K8ssandra by following these docs -
[offline/k8ssandra_setup.md](./k8ssandra_setup.md)

Once K8ssandra is deployed, change the host address in `values/wire-server/values.yaml` to the K8ssandra service address, i.e.
```
sed -i 's/cassandra-external/k8ssandra-cluster-datacenter-1-service.database/g' ./values/wire-server/values.yaml
```

#### Update postgresql secret

If postgresql is part of the deployment, you need to update the postgresql credential in the `values/wire-server/secrets.yaml` file like following as the secrets are stored in the k8s environment.

```bash
For manual deployments or troubleshooting, use the generic sync script:

```bash
d bash
# Sync PostgreSQL password from K8s secret to secrets.yaml
./bin/sync-k8s-secret-to-wire-secrets.sh \
  wire-postgresql-external-secret \
  password \
  values/wire-server/secrets.yaml \
  .brig.secrets.pgPassword \
  .galley.secrets.pgPassword
```

Check the details in the [Postgresql Cluster setup documentation](postgresql-cluster.md#manual-password-synchronization)

#### Deploying Wire-Server

Now deploy `wire-server`:

```
d helm install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```

### Deploying webapp

Update the values in `./values/webapp/prod-values.example.yaml`

Set your domain name with sed:
```
sed -i "s/example.com/YOURDOMAINHERE/g" values/webapp/prod-values.example.yaml
```
and run
```
d helm install webapp ./charts/webapp --values ./values/webapp/prod-values.example.yaml
```

### Deploying team-settings

Update the values in `./values/team-settings/prod-values.example.yaml` and `./values/team-settings/prod-secrets.example.yaml`

Set your domain name with sed:
```
sed -i "s/example.com/YOURDOMAINHERE/g" values/team-settings/prod-values.example.yaml
```
then run
```
d helm install team-settings ./charts/team-settings --values ./values/team-settings/prod-values.example.yaml --values ./values/team-settings/prod-secrets.example.yaml
```

### Deploying account-pages

Update the values in `./values/account-pages/prod-values.example.yaml`

Set your domain name with sed:
```
sed -i "s/example.com/YOURDOMAINHERE/g" values/account-pages/prod-values.example.yaml
```
and run
```
d helm install account-pages ./charts/account-pages --values ./values/account-pages/prod-values.example.yaml
```

### Deploying smallstep-accomp

Update the values in `./values/smallstep-accomp/prod-values.example.yaml`
and then run
```
d helm install smallstep-accomp ./charts/smallstep-accomp --values ./values/smallstep-accomp/prod-values.example.yaml
```


## Directing Traffic to Wire

### Deploy ingress-nginx-controller

This component requires no configuration, and is a requirement for all of the methods we support for getting traffic into your cluster:

```
cp ./values/ingress-nginx-controller/prod-values.example.yaml ./values/ingress-nginx-controller/values.yaml
d helm install ingress-nginx-controller ./charts/ingress-nginx-controller --values ./values/ingress-nginx-controller/values.yaml
```

### Forwarding traffic to your cluster

#### Using network services

The goal of the section is to forward traffic on ports 443 and 80 to the kubernetes node(s) that run(s) ingress service.
Wire expected https traffic port 443 to be forwarded to port 31773 and http traffic on port 80 to be forwarded to port 31772.

#### Through an IP Masquerading Firewall

Your ip masquerading firewall must forward port 443 and port 80 to one of the kubernetes nodes (which must always remain online).
Additionally, if you want to use letsEncrypt CA certificates, items behind your firewall must be redirected to your kubernetes node, when the cluster is attempting to contact the outside IP.

The following instructions are given only as an example. Depending on your network setup different dns masquarading rules are required.
In the following all traffic destined to your wire cluster is going through a single IP masquerading firewall.

##### Incoming SSL Traffic

To prepare determine the interface of your outbound IP:

```bash
export OUTBOUNDINTERFACE=$(ip ro | sed -n "/default/s/.* dev \([enpso0-9]*\) .*/\1/p")
echo "OUTBOUNDINTERFACE is $OUTBOUNDINTERFACE"
```

Please check that `OUTBOUNDINTERFACE` is correctly set, before continuning.

Supply your outside IP address:

```bash
export PUBLICIPADDRESS=<your.ip.address.here>
```

You can do this directly with this one-liner command, which inserts into `$PUBLICIPADDRESS` the IP of the interface with name `$OUTBOUNDINTERFACE` :

```bash
export PUBLICIPADDRESS=$(ip -br addr | awk -v iface="$OUTBOUNDINTERFACE" '$1 == iface {split($3, a, "/"); print a[1]}')
```

Finally you can check the right value is in the environment variable using:

```bash
echo "PUBLICIPADDRESS is $PUBLICIPADDRESS"
```

Then:

1. Find out on which node `ingress-nginx` is running:
```
d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.hostIP
```
2. Use that IP for $KUBENODEIP

```
export KUBENODEIP=<your.kubernetes.node.ip>
```

Or instead of getting the IP manually, you can also do this with a one-liner command:

```bash
export KUBENODEIP=$(sudo docker run --network=host -v ${SSH_AUTH_SOCK:-nonexistent}:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v $HOME/.ssh:/root/.ssh -v $PWD:/wire-server-deploy $WSD_CONTAINER kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.hostIP --no-headers |  awk '{print $3}')
```

then, in case the server owns the public IP (i.e. you can see the IP in `ip addr`), run the following:
```
sudo bash -c "
set -xeo pipefail;

iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $KUBENODEIP:31772;
iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 443 -j DNAT --to-destination $KUBENODEIP:31773;
"
```

If your server is being forwarded traffic from another firewall (you do not see the IP in `ip addr`), run the following:
```
sudo bash -c "
set -eo pipefail;

iptables -t nat -A PREROUTING -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $KUBENODEIP:31772;
iptables -t nat -A PREROUTING -i $OUTBOUNDINTERFACE -p tcp --dport 443 -j DNAT --to-destination $KUBENODEIP:31773;
"
```
or add the corresponding rules to a config file (for UFW, /etc/ufw/before.rules) so they persist after rebooting.

If you are running a UFW firewall, make sure to allow inbound traffic on 443 and 80:
```
sudo bash -c "
set -eo pipefail;

ufw enable;
ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 443;
ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 80;
"
```

By default, the predefined ruleset forwards ingress traffic to kubenode1 (192.168.122.21). To check on which node the ingress controller has been deployed, get the node IP via kubectl:
```
d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.hostIP
```

If the IP returns 192.168.122.21, you can skip the next few steps.
Otherwise, execute these commands:
```
export KUBENODEIP=<your.kubernetes.node.ip>

sudo sed -i -e "s/192.168.122.21/$KUBENODEIP/g" /etc/nftables.conf

sudo systemctl restart nftables
"
```

###### Mirroring the public IP

`cert-manager` has a requirement on being able to reach the kubernetes on its external IP. This might be problematic, because in security conscious environments, the external IP might not owned by any of the kubernetes hosts.

On an IP Masquerading router, you can redirect outgoing traffic from your cluster, i.e. when the cluster asks to connect to your external IP, it will be routed to the kubernetes node inside the cluster.

Make sure `PUBLICIPADDRESS` is exported (see above).

```
export INTERNALINTERFACE=virbr0
sudo bash -c "
set -xeo pipefail;

iptables -t nat -A PREROUTING -i $INTERNALINTERFACE -d $PUBLICIPADDRESS -p tcp --dport 80 -j DNAT --to-destination $KUBENODEIP:31772;
iptables -t nat -A PREROUTING -i $INTERNALINTERFACE -d $PUBLICIPADDRESS -p tcp --dport 443 -j DNAT --to-destination $KUBENODEIP:31773;
"
```

or add the corresponding rules to a config file (for UFW, /etc/ufw/before.rules) so they persist after rebooting.


### Changing the TURN port

FIXME: ansibleize this!
turn's connection port for incoming clients is set to 80 by default. to change it:
on the restund nodes, edit /etc/restund.conf, and replace ":80" with your desired port. for instance, 8080 like above.


### Acquiring / Deploying SSL Certificates:

SSL certificates are required by the nginx-ingress-services helm chart. You can either register and provide your own, or use cert-manager to request certificates from LetsEncrypt.

##### Prepare to deploy nginx-ingress-services

Move the example values for `nginx-ingress-services`:

```
cp ./values/nginx-ingress-services/prod-values.example.yaml ./values/nginx-ingress-services/values.yaml
cp ./values/nginx-ingress-services/prod-secrets.example.yaml ./values/nginx-ingress-services/secrets.yaml
```

#### Bring your own certificates

The `values/nginx-ingress-services/values.yaml` file should be patched for `.Values.tls.useCertManager=false`.
if you generated your SSL certificates yourself, there are two ways to give these to wire:

##### From the command line
if you have the certificate and it's corresponding key available on the filesystem, copy them into the root of the Wire-Server directory, and:

```
d helm install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml --set-file secrets.tlsWildcardCert=certificate.pem --set-file secrets.tlsWildcardKey=key.pem
```

Do not try to use paths to refer to the certificates, as the 'd' command messes with file paths outside of Wire-Server.

##### In your nginx-ingress-services values file
Change the domains in `values.yaml` to your domain. And add your wildcard or SAN certificate that is valid for all these
domains to the `secrets.yaml` file.

Now install the service with helm:

```
d helm install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml --values ./values/nginx-ingress-services/secrets.yaml
```

#### Use letsencrypt generated certificates

If you are using a single external IP and no route then you need to make sure that the cert-manger pods are not deployed on the same node as ingress-nginx-controller node.

To do that...check where ingress-nginx-controller pod is running on, e.g. by running


```
d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```
For e.g. .. if it is `kubenode1`

taint the node

```
d kubectl cordon kubenode1
```

Next step is to install and configure the cert-manager using the cert-manager charts from the offline package.

To enable and configure automatic SSL/TLS certification management for nginx ingress resources, update the `values/nginx-ingress-services/values.yaml` with:

 * set `useCertManager: true` : to tell the nginx-ingress-service to use cert-manager for obtaining and managing SSL certificates, rather than expecting you to provide your own certificates manually.
 * set `certmasterEmail: <your email address>` : is used by cert-manager when requesting certificates from certificate authorities like Let's Encrypt. This email address is important for receiving notifications about certificate expiration or issues.


Set your domain name with sed:
```
sed -i "s/example.com/YOURDOMAINHERE/" values/nginx-ingress-services/values.yaml
```

Install `cert-manager` into a new namespace `cert-manager-ns`.
```
d kubectl create namespace cert-manager-ns
d helm upgrade --install -n cert-manager-ns --set 'installCRDs=true' cert-manager charts/cert-manager
```

Uncordon the node you cordonned earlier:
```
d kubectl uncordon kubenode1
```

Then run:

```
d helm upgrade --install nginx-ingress-services charts/nginx-ingress-services -f values/nginx-ingress-services/values.yaml
```

In order to acquire SSL certificates from letsencrypt, outgoing traffic needs from VMs needs to be enabled temporarily.
With the nftables based Hetzner Server setup, enable this rule and restart nftables:

```
vi /etc/nftables.conf

iifname virbr0 oifname $INF_WAN counter accept comment "allow internet for internal VMs, enable this rule only for letsencrypt cert issue"

sudo systemctl restart nftables
```

Watch the output of the following command to know how your request is going:
```
d kubectl get certificate
```

Once the cert has been issued successfully, the rule above can be disabled again, disallowing outgoing traffic from VMs. Restart the firewall after edits.


#### Old wire-server releases

on older wire-server releases, nginx-ingress-services may fail to deploy. some version numbers of services have changed. make the following changes, and try to re-deploy till it works.

certificate.yaml:
v1alpha2 -> v1
remove keyAlgorithm keySize keyEncoding

certificate-federator.yaml:
v1alpha2 -> v1
remove keyAlgorithm keySize keyEncoding

issuer:
v1alpha2 -> v1

## Installing sftd

For full docs with details and explanations please see https://github.com/wireapp/wire-server-deploy/blob/d7a089c1563089d9842aa0e6be4a99f6340985f2/charts/sftd/README.md

First, make sure you have a certificate for `sftd.<yourdomain>`, or you are using letsencrypt certificate.
for bring-your-own-certificate, this could be the same wildcard or SAN certificate you used at previous steps.

Next, copy `values/sftd/prod-values.example.yaml` to `values/sftd/values.yaml`, and change the contents accordingly.

 * If your turn servers can be reached on their public IP by the SFT service, Wire recommends you enable cooperation between turn and SFT. add a line reading `turnDiscoveryEnabled: true` to `values/sftd/values.yaml`.

edit values/sftd/values.yaml, and select whether you want lets-encrypt certificates, and ensure the alloworigin and the host point to the appropriate domains.

#### Deploying

##### Node Annotations and External IPs.
If you want to restrict SFT to certain nodes, make sure that in your inventory file you have annotated all of the nodes that are able to run sftd workloads with a node label indicating they are to be used, and their external IP, if they are behind a 1:1 firewall (Wire recommends this.).
```
kubenode3 node_labels="{'wire.com/role': 'sftd'}" node_annotations="{'wire.com/external-ip': 'XXXX'}"
```

If you failed to perform the above step during the ansible deployment of your sft services, you can perform then manually:
```
d kubectl annotate node kubenode1 wire.com/external-ip=178.63.60.45
d kubectl label node kubenode1 wire.com/role=sftd
```

##### A selected group of kubernetes nodes:
By default, the replicaCount in `values/sftd/values.yaml` is set to 3. Change it to the number of nodes on which you want to deploy sftd server.

If you are restricting SFT to certain nodes, use `nodeSelector` to run on specific nodes (**replacing the example.com domains with yours**):
```
d helm upgrade --install sftd ./charts/sftd --set 'nodeSelector.wire\.com/role=sftd' --values values/sftd/values.yaml
```

##### All kubernetes nodes.
If you are not doing that, omit the `nodeSelector` argument:

```
d helm upgrade --install sftd ./charts/sftd --values values/sftd/values.yaml
```

##### Specifying your certificates.

If you bring your own certificates, you can specify them with:

```
d helm upgrade --install sftd ./charts/sftd \
  --set-file tls.crt=/path/to/tls.crt \
  --set-file tls.key=/path/to/tls.key \
  --values values/sftd/values.yaml
```


## Coturn.

To deploy coturn on your new installation, go to the following link and follow the instructions there:

[Installing Coturn](coturn.md)


## Installing fluent-bit

To collect and distribute logs to database or log servers such as Elasticsearch, syslog, etc.
Copy `values/fluent-bit/prod-values.example.yaml` to `values/fluent-bit/values.yaml` and edit the file accordingly. Sample values for Elasticsearch and syslog are provided in the file.

```
cp values/fluent-bit/prod-values.example.yaml values/fluent-bit/values.yaml
```

and, install the fluent-bit helm chart

```
d helm upgrade --install fluent-bit ./charts/fluent-bit --values values/fluent-bit/values.yaml
```

Make sure that traffic is allowed from your kubernetes nodes to your destination server (elasticsearch or syslog).

## Configure Prometheus

To scrape metrics from wire systems and export those to your desired Observability tool, preferably grafana, configure prometheus operator.
Follow the [Instrument monitoring guidelines](./instrument_monitoring.md) to setup monitoring for wire.

## Appendixes

### Syncing time on cassandra nodes
The nodes running cassandra (`ansnode` 1, 2 and 3) require precise synchronization of their clock.

In case the cassandra migration doesn't complete, it might be probably due to the clock not being in sync.

To sync them, run the following ansible playbook -
```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/sync_time.yml
```

The above playbook will configure NTP on all Cassandra nodes, assigns first node as the authoritative node. All other nodes will sync their time with the authoritative node.

### Resetting the k8s cluster
To reset the k8s cluster, run the following command:
```
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/roles-external/kubespray/reset.yml --skip-tags files
```
You can remove the `--skip-tags files` option if you want to remove all the loaded container images as well.

After that, to reinstall the cluster, comment out the steps in the `offline-cluster.sh` script, such as setup-offline-sources and seed-offline-containerd to avoid re-downloading the container images to save time, and run -
```
d ./bin/offline-cluster.sh
```
