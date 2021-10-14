# How to install wire

We have a pipeline in  `wire-server-deploy` producing container images, static
binaries, ansible playbooks, debian package sources and everything required to
install Wire.

On your machine (we call this the "admin host"), you need to have `docker`
installed (or any other compatible container runtime really, even though
instructions may need to be modified). See [how to install
docker](https://docker.com) for instructions.

On ubuntu 18.04, connected to the internet:

```
apt install docker.io
```

Ensure the user you are using for the install has permission to run docker, or add 'sudo' to the docker commands below.

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

Open `ansible/inventory/offline/99-static`. Here you will describe the topology
of your offline deploy.  There's instructions in the comments on how to set
everything up. You can also refer to extra information here.
https://docs.wire.com/how-to/install/ansible-VMs.html

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
  should be set to the private network interface to too.

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

## Generating secrets

Minio and restund services have shared secrets with the `wire-server` helm chart. We have a utility
script that generates a fresh set of secrets for these components.

Please run:
```
./bin/offline-secrets.sh
```

This should generate two files. `./ansible/inventory/group_vars/all/secrets.yaml` and `values/wire-server/secrets.yaml`.


## Deploying Kubernetes, Restund and stateful services

In order to deploy all the ansible-managed services you can run:
```
d ./bin/offline-cluster.sh
```

However we now explain each step of the script step by step too. For better understanding.

Copy over binaries and debs, serves assets from the asset host, and configure
other hosts to fetch debs from it:

```
d ansible-playbook -i ./ansible/inventory/offline ansible/setup-offline-sources.yml
```

Run kubespray until docker is installed and runs. This allows us to preseed the docker containers that
are part of the offline bundle:

```
d ansible-playbook -i ./ansible/inventory/offline ansible/kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine
```

Now; run the restund playbook until docker is installed:
```
d ansible-playbook -i ./ansible/inventory/offline ansible/restund.yml --tags docker
```

With docker being installed on all nodes that need it, seed all container images:

```
d ansible-playbook -i ./ansible/inventory/offline ansible/seed-offline-docker.yml
```

Run the rest of kubespray. This should bootstrap a kubernetes cluster successfully:

```
d ansible-playbook -i ./ansible/inventory/offline ansible/kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine
```


Ensure the cluster comes up healthy. The container also contains kubectl, so check the node status:

```
d kubectl get nodes -owide
```
They should all report ready.

Now, deploy all other services which don't run in kubernetes.

```
d ansible-playbook -i ./ansible/inventory/offline ansible/restund.yml
d ansible-playbook -i ./ansible/inventory/offline ansible/cassandra.yml
d ansible-playbook -i ./ansible/inventory/offline ansible/elasticsearch.yml
d ansible-playbook -i ./ansible/inventory/offline ansible/minio.yml
```



Afterwards, run the following playbook to create helm values that tell our helm charts
what the IP addresses of cassandra, elasticsearch and minio are.
```
d ansible-playbook -i ./ansible/inventory/offline ansible/helm_external.yml
```


## Deploying wire-server using helm

It's now time to deploy the helm charts on top of kubernetes, installing the Wire platform.

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

Next, we have 4 services that need to be deployed but need no additional configuration:
```
d helm install fake-aws ./charts/fake-aws --values ./values/fake-aws/prod-values.example.yaml
d helm install demo-smtp ./charts/demo-smtp --values ./values/demo-smtp/prod-values.example.yaml
d helm install databases-ephemeral ./charts/databases-ephemeral/ --values ./values/databases-ephemeral/values.yaml
d helm install reaper ./charts/reaper
```

Next, move `./values/wire-server/prod-values.example.yaml` to `./values/wire-server/values.yaml`.
Inspect all the values and adjust domains to your domains where needed.

Add the IPs of your `restund` servers to the `turnStatic.v2` list.:
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

Now deploy `wire-server`:

```
d helm install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```


## Configuring ingress

First, install the `nginx-ingress-controller`. This requires no configuration:

```
d helm install nginx-ingress-controller ./charts/nginx-ingress-controller
```

Next, move the example values for `nginx-ingress-services`:
```
mv ./values/nginx-ingress-services/{prod-values.example.yaml,values.yaml}
mv ./values/nginx-ingress-services/{prod-secrets.example.yaml,secrets.yaml}
```

Change the domains in `values.yaml` to your domain. And add your wildcard or SAN certificate that is valid for all these
domains to the `secrets.yaml` file.


Now install the ingress:

```
d helm install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml  --values ./values/nginx-ingress-services/secrets.yaml
```



### Installing sftd

For full docs with details and explanations please see https://github.com/wireapp/wire-server-deploy/blob/d7a089c1563089d9842aa0e6be4a99f6340985f2/charts/sftd/README.md

First, make sure you have a certificate for `sftd.<yourdomain>`. This could be the same wildcard or SAN certificate
you used at previous steps.

If you want to restrict SFT to certain nodes, make sure that in your inventory
you have annotated all the nodes that are able to run sftd workloads correctly.
```
kubenode3 node_labels="{'wire.com/role': 'sftd'}" node_annotations="{'wire.com/external-ip': 'XXXX'}"
```

If these weren't already set; you should rerun :
```
d ansible-playbook -i ./ansible/inventory/offline ansible/kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine
```


If you are restricting SFT to certain nodes, use `nodeSelector` to run on specific nodes (of course **replace the domains with yours**):
```
d helm upgrade --install sftd ./charts/sftd \
  --set 'nodeSelector.wire\.com/role=sftd' \
  --set host=sftd.example.com \
  --set allowOrigin=https://webapp.example.com \
  --set-file tls.crt=/path/to/tls.crt \
  --set-file tls.key=/path/to/tls.key
```

If you are not doing that, omit the `nodeSelector` argument:
```
d helm upgrade --install sftd ./charts/sftd \
  --set host=sftd.example.com \
  --set allowOrigin=https://webapp.example.com \
  --set-file tls.crt=/path/to/tls.crt \
  --set-file tls.key=/path/to/tls.key
```
