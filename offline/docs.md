# How to install wire

We have a pipeline in  `wire-server-deploy` producing container images, static
binaries, ansible playbooks, debian package sources and everything required to
install Wire.

## Installing docker
On your machine (we call this the "admin host"), you need to have `docker`
installed (or any other compatible container runtime really, even though
instructions may need to be modified). See [how to install
docker](https://docker.com) for instructions.

On ubuntu 18.04, connected to the internet:

```
apt install docker.io
```

Ensure the user you are using for the install has permission to run docker, or add 'sudo' to the docker commands below.


## Downloading and extracting the artifact
Create a fresh workspace to download the artifacts:

```
$ cd ...  # you pick a good location!
```

Obtain the latest airgrap artifact for wire-server-deploy. Please contact us to get it for now. We are
working on publishing a list of airgap artifacts.

Extract the above listed artifacts into your workspace:

```
$ wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-<HASH>.tgz
$ tar xvzf wire-server-deploy-static-<HASH>.tgz
```
Where the HASH above is the hash of your deployment artifact, given to you by Wire, or acquired by looking at the above build job.
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
ansible 2.9.12
  config file = /home/arian/.ansible.cfg
  configured module search path = ['/home/arian/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /nix/store/gfrhkj3j53znj0vyvkqkbn56n2mh708k-python3.8-ansible-2.9.12/lib/python3.8/site-packages/ansible
  executable location = /nix/store/gfrhkj3j53znj0vyvkqkbn56n2mh708k-python3.8-ansible-2.9.12/bin/ansible
  python version = 3.8.7 (default, Dec 21 2020, 17:18:55) [GCC 10.2.0]

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
   contains Restund.
 - `debs.tar`
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

### Configuring kubernetes and etcd

You'll need at least 3 `kubenode`s.  3 of them should be added to the
`[kube-master]`, `[etcd]`  and `[kube-node]` groups of the inventory file.  Any
additional nodes should only be added to the `[kube-node]` group.

### Setting up databases and kubernetes to talk over the correct (private) interface

* For `kubenode`s make sure that `ip` is set to the IP on which the nodes should talk among eachother.
* Make sure that `assethost` is present in the inventory file with the correct `ansible_host` and `ip` values
* Make sure that `cassandra_network_interface` is set to the interface on which
  the kubenodes can reach cassandra and on which the cassandra nodes
  communicate among eachother. Your private network.
* Similarly `elasticsearch_network_interface` and `minio_network_interface`
  should be set to the private network interface as well.

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

### Marking kubenode for calling server (SFT)

The SFT Calling server should be running on a kubernetes nodes that are connected to the public internet.
If not all kubernetes nodes match these criteria, you should specifically label the nodes that do match
these criteria, so that we're sure SFT is deployed correctly.


By using a `node_label` we can make sure SFT is only deployed on a certain node like `kubenode4`

```
kubenode4 node_labels="wire.com/role=sftd" node_annotations="{'wire.com/external-ip': 'XXXX'}"
```

If the node does not know its onw public IP (e.g. becuase it's behind NAT) then you should also set
the `wire.com/external-ip` annotation to the public IP of the node.

### Configuring MinIO

In order to automatically generate deeplinks, Edit the minio variables in `[minio:vars]` (`prefix`, `domain` and `deeplink_title`) by replacing `example.com` with your own domain.

## Generating secrets

Minio and restund services have shared secrets with the `wire-server` helm chart. We have a utility
script that generates a fresh set of secrets for these components.

Please run:
```
./bin/offline-secrets.sh
```

This should generate two files. `./ansible/inventory/group_vars/all/secrets.yaml` and `values/wire-server/secrets.yaml`.

## Deploying Kubernetes, Restund and stateful services

### WORKAROUND: old debian key
All of our debian archives up to version 4.12.0 used a now-outdated debian repository signature. Some modifications are required to be able to install everything properly.

First, gather a copy of the 'setup-offline-sources.yml' file from: https://raw.githubusercontent.com/wireapp/wire-server-deploy/kvm_support/ansible/setup-offline-sources.yml .
```
wget https://raw.githubusercontent.com/wireapp/wire-server-deploy/kvm_support/ansible/setup-offline-sources.yml
```
copy it into the ansible/ directory:
```
cp ansible/setup-offline-sources.yml ansible/setup-offline-sources.yml.backup
cp setup-offline-sources.yml ansible/
```

Open it with your prefered text editor and edit the following:
* find a big block of comments and uncomment everything in it `- name: trust everything...`
* after the block you will find `- name: Register offline repo key...`. Comment out that segment (do not comment out the part with `- name: Register offline repo`!)

Then disable checking for outdated signatures by editing the following file:
```
ansible/roles-external/kubespray/roles/container-engine/docker/tasks/main.yml
```
* comment out the block with -name: ensure docker-ce repository public key is installed...
* comment out the next block -name: ensure docker-ce repository is enabled

Now you are ready to start deploying services.

#### WORKAROUND: dependency
some ubuntu systems do not have GPG by default. wire assumes this is already present. ensure you have gpg installed on all of your nodes before continuing to the next step.

### Deploying with Ansible

In order to deploy all the ansible-managed services you can run:
```
# d ./bin/offline-cluster.sh
```
... However a conservitave approach is to perform each step of the script step by step, for better understanding, and better handling of errors..

#### Populate the assethost, and prepare to install images from it.

Copy over binaries and debs, serves assets from the asset host, and configure
other hosts to fetch debs from it:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/setup-offline-sources.yml
```
If this step fails partway, and you know that parts of it completed, the `--skip-tags debs,binaries,containers,containers-helm,containers-other` tags may come in handy.

#### Kubernetes, part 1
Run kubespray until docker is installed and runs. This allows us to preseed the docker containers that
are part of the offline bundle:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine
```

#### Restund
Now; run the restund playbook until docker is installed:
```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/restund.yml --tags docker
```


#### Pushing docker containers to kubenodes, and restund nodes.
With docker being installed on all nodes that need it, seed all container images:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/seed-offline-docker.yml
```

#### Kubernetes, part 2
Run the rest of kubespray. This should bootstrap a kubernetes cluster successfully:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine
```

#### Ensuring kubernetes is healthy.

Ensure the cluster comes up healthy. The container also contains kubectl, so check the node status:

```
d kubectl get nodes -owide
```
They should all report ready.


#### Non-kubernetes services (restund, cassandra, elasticsearch, minio)
Now, deploy all other services which don't run in kubernetes.

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/restund.yml
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/cassandra.yml
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/elasticsearch.yml
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/minio.yml
```

Afterwards, run the following playbook to create helm values that tell our helm charts
what the IP addresses of cassandra, elasticsearch and minio are.

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/helm_external.yml
```

### Deploying Wire

It's now time to deploy the helm charts on top of kubernetes, installing the Wire platform.

#### Finding the stateful services
First.  Make kubernetes aware of where alll the external stateful services are by running:

```
d helm install cassandra-external ./charts/cassandra-external --values ./values/cassandra-external/values.yaml
d helm install elasticsearch-external ./charts/elasticsearch-external --values ./values/elasticsearch-external/values.yaml
d helm install minio-external ./charts/minio-external --values ./values/minio-external/values.yaml
```

Also copy the values file for `databases-ephemeral` as it is required for the next step:

```
cp values/databases-ephemeral/prod-values.example.yaml values/databases-ephemeral/values.yaml
```

#### Deploying stateless dependencies
Next, we have 4 services that need to be deployed but need no additional configuration:
```
d helm install fake-aws ./charts/fake-aws --values ./values/fake-aws/prod-values.example.yaml
d helm install demo-smtp ./charts/demo-smtp --values ./values/demo-smtp/prod-values.example.yaml
d helm install databases-ephemeral ./charts/databases-ephemeral/ --values ./values/databases-ephemeral/values.yaml
d helm install reaper ./charts/reaper
```

#### Preparing your values

Next, move `./values/wire-server/prod-values.example.yaml` to `./values/wire-server/values.yaml`.
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
sed -i 's/example.com/<your-domain>/g' values.yaml
```


#### Deploying Wire-Server

Now deploy `wire-server`:

```
d helm install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```

## Directing Traffic to Wire

### Deploy nginx-ingress-controller

This component requires no configuration, and is a requirement for all of the methods we support for getting traffic into your cluster:
```
d helm install nginx-ingress-controller ./charts/nginx-ingress-controller
```

### Forwarding traffic to your cluster

#### Using network services

Most enterprises have network service teams to forward traffic appropriately. Ask that your network team forward TCP port 443 to each one of the kubernetes servers on port 31773. ask the same for port 80, directing it to 31772.

If they ask for clarification, a longer way of explaining it is "wire expects https traffic to be on port 31773, and http traffic to go to port 80. a load balancing rule needs to be in place, so that no matter which kubernetes host is up or down, the router will direct traffic to one of the operational kubernetes nodes. any node that accepts connections on port 31773 and 31772 can be considered as operational."

#### Through an IP Masquerading Firewall

Your ip masquerading firewall must forward port 443 and port 80 to one of the kubernetes nodes (which must always remain online).
Additionally, if you want to use letsEncrypt CA certificates, items behind your firewall must be redirected to your kubernetes node, when the cluster is attempting to contact the outside IP.

The following instructions are given only as an example. 
Properly configuring IP Masquerading requires a seasoned linux administrator with deep knowledge of networking. 
They assume all traffic destined to your wire cluster is going through a single IP masquerading firewall, running some modern version of linux.

##### Incoming SSL Traffic

Here, you should check the ethernet interface name for your outbound IP.
```
ip ro | sed -n "/default/s/.* dev \([enpso0-9]*\) .*/export OUTBOUNDINTERFACE=\1/p"
```

This will return a shell command setting a variable to your default interface. copy and paste it. next, supply your outside IP address:
```
export PUBLICIPADDRESS=<your.ip.address.here>
```

Select one of your kubernetes nodes that you are fine with losing service if it is offline:
```
export KUBENODE1IP=<your.kubernetes.node.ip>
```

then run the following:
```
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $KUBENODE1IP:80
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 443 -j DNAT --to-destination $KUBENODE1IP:443
```
or add an appropriate rule to a config file (for UFW, /etc/ufw/before.rules)

Then ssh into the first kubenode and make the following configuration:
```
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 31773
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 31772
```

###### Mirroring the public IP

cert-manager has a requirement on being able to reach the kubernetes on it's external IP. this is trouble, because in most security concious environments, the external IP is not owned by any of the kubernetes hosts.

on an IP Masquerading router, you can redirect outgoing traffic from your cluster, that is to say, when the cluster asks to connect to your external IP, you can instead choose to send it to a kubernetes node inside of the cluster.
```
export INTERNALINTERFACE=br0
sudo iptables -t nat -A PREROUTING -i $INTERNALINTERFACE -d $PUBLICIPADDRESS -p tcp -m multiport --dports 80,443 -j DNAT --to-destination $KUBENODE1IP
```

### Incoming Calling Traffic

Here, you should check the ethernet interface name for your outbound IP.
```
ip ro | sed -n "/default/s/.* dev \([enps0-9]*\) .*/export OUTBOUNDINTERFACE=\1/p"
```

This will return a shell command setting a variable to your default interface. copy and paste it. next, supply your outside IP address:
```
export PUBLICIPADDRESS=<your.ip.address.here>
```

Select one of your kubernetes nodes that you are fine with losing service if it is offline:
```
export RESTUND01IP=<your.restund.ip>
```

then run the following:
```
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $RESTUND01IP:80
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p udp --dport 80 -j DNAT --to-destination $RESTUND01IP:80
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p udp -m udp --dport 32768:60999 -j DNAT --to-destination $RESTUND01IP
```
or add an appropriate rule to a config file (for UFW, /etc/ufw/before.rules)

### Changing the TURN port.

FIXME: ansibleize this!
turn's connection port for incoming clients is set to 80 by default. to change it:
on the restund nodes, edit /etc/restund.conf, and replace ":80" with your desired port. for instance, 8080 like above.


### Acquiring / Deploying SSL Certificates:

SSL certificates are required by the nginx-ingress-services helm chart. You can either register and provide your own, or use cert-manager to request certificates from LetsEncrypt.

##### Prepare to deploy nginx-ingress-services

Move the example values for `nginx-ingress-services`:
```
mv ./values/nginx-ingress-services/{prod-values.example.yaml,values.yaml}
mv ./values/nginx-ingress-services/{prod-secrets.example.yaml,secrets.yaml}
```

#### Bring your own certificates

if you generated your SSL certificates yourself, there are two ways to give these to wire:

##### From the command line
if you have the certificate and it's corresponding key available on the filesystem, copy them into the root of the Wire-Server directory, and:

```
d helm install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml --set-file secrets.tlsWildcardCert=certificate.pem --set-file secrets.tlsWildcardKey=key.pem
```

Do not try to use paths to refer to the certificates, as the 'd' command messes with file paths outside of Wire-Server.

##### In your nginx config
Change the domains in `values.yaml` to your domain. And add your wildcard or SAN certificate that is valid for all these
domains to the `secrets.yaml` file.

Now install the service with helm:

```
d helm install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml --values ./values/nginx-ingress-services/secrets.yaml
```

#### Use letsencrypt generated certificates

first, download cert manager, and place it in the appropriate location:
```
wget https://charts.jetstack.io/charts/cert-manager-v1.9.1.tgz
mkdir tmp
cd tmp
tar -xzf ../cert-manager-*.tgz
ls
cd ..
 mv tmp/cert-manager/ charts/
rm -rf tmp
```

edit values/nginx-ingress-services/values.yaml , to tell ingress-ingress-services to use cert-manager:
 * set useCertManager: true
 * set certmasterEmail: your.email.address

set your domain name with sed:
```
sed -i "s/example.com/YOURDOMAINHERE/" values/nginx-ingress-services/values.yaml
```

UNDER CONSTRUCTION:
```
d kubectl create namespace cert-manager-ns
d helm upgrade --install -n cert-manager-ns --set 'installCRDs=true' cert-manager charts/cert-manager
d helm upgrade --install nginx-ingress-services charts/nginx-ingress-services -f values/nginx-ingress-services/values.yaml
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

 * If your turn servers can be reached on their public IP by the SFT service, Wire recommends you enable cooperation between turn and SFT. add a line reading `turnDiscoveryEnabled: true` to your values file.

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
d helm upgrade --install sftd ./charts/sftd \
  --set 'nodeSelector.wire\.com/role=sftd' \
  --values values/sftd/values.yaml
```

##### All kubernetes nodes.
If you are not doing that, omit the `nodeSelector` argument:
```
d helm upgrade --install sftd ./charts/sftd \
  --set-file tls.crt=/path/to/tls.crt \
  --set-file tls.key=/path/to/tls.key \
  --values values/sftd/values.yaml
```
