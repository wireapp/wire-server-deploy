# How to install wire

We have a pipeline in  `wire-server-deploy` producing container images, static
binaries, ansible playbooks, debian package sources and everything required to
install Wire.

## Installing docker
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
ansible [core 2.11.6] 
  config file = /wire-server-deploy/ansible/ansible.cfg
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /nix/store/yqrs358szd85iapw6xpsh1q852f5r8wd-python3.9-ansible-core-2.11.6/lib/python3.9/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /nix/store/yqrs358szd85iapw6xpsh1q852f5r8wd-python3.9-ansible-core-2.11.6/bin/ansible
  python version = 3.9.10 (main, Jan 13 2022, 23:32:03) [GCC 10.3.0]
  jinja version = 3.0.3
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
 - `containers-other.tar`
   These are other container images, not deployed inside k8s. Currently, only
   contains `restund`.
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

##### Adding host entries
When editing the inventory, you only need seven entries in the '[all]' section. One entry for each of the VMs you are running.
Edit the 'kubenode' entries, and the 'assethost' entry like normal.

Instead of creating separate cassandra, elasticsearch, and minio entries, create three 'ansnode' entries, similar to the following:
```
ansnode1 ansible_host=172.16.0.132
ansnode2 ansible_host=172.16.0.133
ansnode3 ansible_host=172.16.0.134
```

##### Updating Group Membership
Afterwards, you need to update the lists of what nodes belong to which group, so ansible knows what to install on these nodes.

Add all three ansnode entries into the `cassandra` `elasticsearch`, and `minio` sections. They should look like the following:
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
```

Add two of the ansnode entries into the `restund` section
```
[restund]
ansnode1
ansnode2
```

Add one of the ansnode entries into the `cassandra_seed` section.
```
[cassandra_seed]
ansnode1
```

### Configuring kubernetes and etcd

You'll need at least 3 `kubenode`s.  3 of them should be added to the
`[kube-master]`, `[etcd]`  and `[kube-node]` groups of the inventory file.  Any
additional nodes should only be added to the `[kube-node]` group.

### Setting up databases and kubernetes to talk over the correct (private) interface
If you are deploying wire on servers that are expected to use one interface to talk to the public, and a separate interface to talk amongst themselves, you will need to add "ip=" declarations for the private interface of each node. for instance, if the first kubenode was expected to talk to the world on 172.16.0.129, but speak to other wire services (kubernetes, databases, etc) on 192.168.0.2, you should edit its entry like the following:
```
kubenode1 ansible_host=172.16.0.129 ip=192.168.0.2
```
Do this for all of the instances.

### Setting up Database network interfaces.
* Make sure that `assethost` is present in the inventory file with the correct `ansible_host` (and `ip` values if required)
* Make sure that `cassandra_network_interface` is set to the name of the network interface on which
  the kubenodes should talk to cassandra and on which the cassandra nodes
  should communicate among each other. Run `ip addr` on one of the cassandra nodes to determine the network interface names, and which networks they correspond to.  For example, if you set up the cassandra nodes via virt-manager, then the interface will be named `enp1s0`. 
* Similarly `elasticsearch_network_interface` and `minio_network_interface`
  should be set to the network interface names you want elasticsearch and minio to communicate with kubernetes with, as well.
  


### Configuring Restund

Restund is deployed for NAT-hole punching and relaying. So that 1-to-1 calls
can be established between Wire users. Restund needs to be directly publicly
reachable on a public IP.

If you need Restund to listen on a different interface than the default gateway, set `restund_network_interface`

If the interface on which Restund is listening does not know its own public IP
(e.g. because it is behind NAT itself) extra configuration is necessary. Please provide the public IP on which
Restund is available as `restund_peer_udp_advertise_addr`.

Due to this *NAT-hole punching* relay purpose and depending on where the Restund instance resides within your network
topology, it could be used to access private services. We consider this to be unintended and thus set a couple
of network rules on a Restund instance. If egress traffic to certain private network ranges should still
be allowed, you may adjust `restund_allowed_private_network_cidrs` according to your setup.
If you install restund together with other services on the same machine you need to set `restund_allowed_private_network_cidrs`
for these services to communicate over the private network.

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

### Configuring rabbitmq

Add the nodes in which you want to run rabbitmq to the `[rmq-cluster]` group. Also, update the `ansible/roles/rabbimq-cluster/defaults/main.yml` file with the correct configurations for your environment.

Important: RabbitMQ nodes address each other using a node name, for e.g rabbitmq@ansnode1
Please refer to official doc and configure your DNS based on the setup - https://www.rabbitmq.com/clustering.html#cluster-formation-requirements

For adding entries to local host file(/etc/hosts), run
```
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/roles/rabbitmq-cluster/tasks/configure_dns.yml
```



### Example hosts.ini

Here is an example `hosts.ini` file that was used in a succesfull example deployment, for reference. It might not be exactly what is needed for your deployment, but it should work for the KVM 7-machine deploy:

```
[all]
kubenode1 ansible_host=172.16.0.129
kubenode2 ansible_host=172.16.0.130
kubenode3 ansible_host=172.16.0.131
ansnode1 ansible_host=172.16.0.132
ansnode2 ansible_host=172.16.0.133
ansnode3 ansible_host=172.16.0.134
assethost ansible_host=172.16.0.128

[all:vars]
ansible_user = demo
ansible_password = fai
ansible_become_password = fai

[cassandra:vars]
cassandra_network_interface = enp1s0

[elasticsearch:vars]
elasticsearch_network_interface = enp1s0

[minio:vars]
minio_network_interface = enp1s0
prefix = ""
domain = "example.com"
deeplink_title = "wire demo environment, example.com"

[restund:vars]
restund_uid = root
restund_allowed_private_network_cidrs=172.16.0.1/24

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

# Note: If you install restund on the same nodes as other services
# you need to set `restund_allowed_private_network_cidrs`
[restund]
ansnode1
ansnode2

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

Minio and restund services have shared secrets with the `wire-server` helm chart. Run the folllowing script that generates a fresh set of secrets for these components:

```
./bin/offline-secrets.sh
```

This should generate two files. `./ansible/inventory/group_vars/all/secrets.yaml` and `values/wire-server/secrets.yaml`.

## Deploying Kubernetes, Restund and stateful services

In order to deploy all the services run:
```
d ./bin/offline-cluster.sh
```
In case any of the steps in this script fail, see the notes in the comments that accompany each step.
Comment out steps that have already completed when re-running the scripts.

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

#### Troubleshooting restund

In case the restund firewall fails to start. Fix

On each ansnode you set in the `[restund]` section of the `hosts.ini` file

Delete the outbound rule to 172.16.0.0/12

```
sudo ufw status numbered;
```

Then find the right number and delete it

```
ufw delete <right number>;
```

#### Ensuring kubernetes is healthy.

Ensure the cluster comes up healthy. The container also contains kubectl, so check the node status:

```
d kubectl get nodes -owide
```
They should all report ready.


#### Enable the ports colocated services run on:
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

Afterwards, run the following playbook to create helm values that tell our helm charts
what the IP addresses of cassandra, elasticsearch, minio and rabbitmq are.

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/helm_external.yml
```

#### Installing Rabbitmq

To install the rabbitmq,
First copy the value and secret file:
```
cp ./values/rabbitmq/prod-values.example.yaml ./values/rabbitmq/values.yaml
cp ./values/rabbitmq/prod-secrets.example.yaml ./values/rabbitmq/secrets.yaml
```

Now, update the `./values/rabbitmq/values.yaml` and `./values/rabbitmq/secrets.yaml` with correct values as per needed.

Deploy the rabbitmq helm chart -
```
d helm upgrade --install rabbitmq ./charts/rabbitmq --values ./values/rabbitmq/values.yaml --values ./values/rabbitmq/secrets.yaml
```

### Deploying Wire

It's now time to deploy the helm charts on top of kubernetes, installing the Wire platform.

#### Finding the stateful services
First.  Make kubernetes aware of where alll the external stateful services are by running:

```
d helm install cassandra-external ./charts/cassandra-external --values ./values/cassandra-external/values.yaml
d helm install elasticsearch-external ./charts/elasticsearch-external --values ./values/elasticsearch-external/values.yaml
d helm install minio-external ./charts/minio-external --values ./values/minio-external/values.yaml
d helm install rabbitmq-external ./charts/rabbitmq-external --values ./values/rabbitmq-external/values.yaml
```

#### Deploying stateless dependencies

Also copy the values file for `databases-ephemeral` as it is required for the next step:

```
cp values/databases-ephemeral/prod-values.example.yaml values/databases-ephemeral/values.yaml
# edit values.yaml if necessary
d helm install databases-ephemeral ./charts/databases-ephemeral/ --values ./values/databases-ephemeral/values.yaml
```

Next, three more services that need no additional configuration need to be deployed:
```
d helm install fake-aws ./charts/fake-aws --values ./values/fake-aws/prod-values.example.yaml
d helm install demo-smtp ./charts/demo-smtp --values ./values/demo-smtp/prod-values.example.yaml
d helm install reaper ./charts/reaper
```

#### Preparing your values

Next, move `./values/wire-server/prod-values.example.yaml` to `./values/wire-server/values.yaml`.

```
cp ./values/wire-server/prod-values.example.yaml ./values/wire-server/values.yaml
```

Inspect all the values and adjust domains to your domains where needed.

Add the IPs of your `restund` servers to the `turnStatic.v2` list:
```yaml
  turnStatic:
    v1: []
    v2:
      - "turn:<IP of restund1>:80"
      - "turn:<IP of restund2>:80"
      - "turn:<IP of restund1>:80?transport=tcp"
      - "turn:<IP of restund2>:80?transport=tcp"
```

Open up `./values/wire-server/secrets.yaml` and inspect the values. In theory
this file should have only generated secrets, and no additional secrets have to
be added, unless additional options have been enabled.

Open up `./values/wire-server/values.yaml` and replace example.com and other domains and subdomain with your domain. You can do it with:

```
sed -i 's/example.com/<your-domain>/g' ./values/wire-server/values.yaml
```


#### Deploying Wire-Server

Now deploy `wire-server`:

```
d helm install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
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

```
export OUTBOUNDINTERFACE=$(ip ro | sed -n "/default/s/.* dev \([enpso0-9]*\) .*/\1/p")
echo "OUTBOUNDINTERFACE is $OUTBOUNDINTERFACE"
```

Please check that `OUTBOUNDINTERFACE` is correctly set, before continuning.

Supply your outside IP address:

```
export PUBLICIPADDRESS=<your.ip.address.here>
```

1. Find out on which node `ingress-nginx` is running:
```
d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```
3. Get the IP of this node by running `ip address` on that node
4. Use that IP for $KUBENODEIP

```
export KUBENODEIP=<your.kubernetes.node.ip>
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

###### Mirroring the public IP

`cert-manager` has a requirement on being able to reach the kubernetes on its external IP. This might be problematic, because in security concious environments, the external IP might not owned by any of the kubernetes hosts.

On an IP Masquerading router, you can redirect outgoing traffic from your cluster, i.e. when the cluster asks to connect to your external IP, it will be routed to the kubernetes node inside the cluster.

Make sure `PUBLICIPADDRESS` is exported (see above).

```
export INTERNALINTERFACE=br0
sudo bash -c "
set -xeo pipefail;

iptables -t nat -A PREROUTING -i $INTERNALINTERFACE -d $PUBLICIPADDRESS -p tcp --dport 80 -j DNAT --to-destination $KUBENODEIP:31772;
iptables -t nat -A PREROUTING -i $INTERNALINTERFACE -d $PUBLICIPADDRESS -p tcp --dport 443 -j DNAT --to-destination $KUBENODEIP:31773;
"
```

or add the corresponding rules to a config file (for UFW, /etc/ufw/before.rules) so they persist after rebooting.

### Incoming Calling Traffic

Make sure `OUTBOUNDINTERFACE` and `PUBLICIPADDRESS` are exported (see above).

Select one of your kubernetes nodes that hosts restund:

```
export RESTUND01IP=<your.restund.ip>
```

then run the following:
```
sudo bash -c "
set -eo pipefail;

iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $RESTUND01IP:80;
iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p udp --dport 80 -j DNAT --to-destination $RESTUND01IP:80;
iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p udp -m udp --dport 32768:60999 -j DNAT --to-destination $RESTUND01IP;
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

first, download cert manager, and place it in the appropriate location:
```
wget https://charts.jetstack.io/charts/cert-manager-v1.9.1.tgz
tar -C ./charts -xvzf cert-manager-v1.9.1.tgz
```

In case `values.yaml` and `secrets.yaml` doesn't exist yet in `./values/nginx-ingress-services` create them from templates
```
cp ./values/nginx-ingress-services/prod-secrets.example.yaml ./values/nginx-ingress-services/secrets.yaml
cp ./values/nginx-ingress-services/prod-values.example.yaml ./values/nginx-ingress-services/values.yaml
```
and customize.

Edit `values.yaml`:

 * set `useCertManager: true`
 * set `certmasterEmail: <your email address>`

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

Watch the output of the following command to know how your request is going:
```
d kubectl get certificate
```

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


## Appendixes


The nodes running cassandra (`ansnode` 1, 2 and 3) require precise synchronization of their clock.

In case the cassandra migration doesn't complete, it might be probably due to the clock not being in sync.

To sync them, run the following ansible playbook -
```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/sync_time.yml
```

The above playbook will configure NTP on all Cassandra nodes, assigns first node as the authoritative node. All other nodes will sync their time with the authoritative node.
