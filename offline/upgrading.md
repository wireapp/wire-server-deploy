# How to upgrade wire (services only)

We have a pipeline in  `wire-server-deploy` producing container images, static
binaries, ansible playbooks, debian package sources and everything required to
install Wire.

Create a fresh workspace to download the new artifacts:

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

## Comparing the inventory

Compare the inventory from your old install to the inventory of your new install.

Open `ansible/inventory/offline/99-static`. Here you will describe the topology
of your offline deploy.  There's instructions in the comments on how to set
everything up. You can also refer to extra information here.
https://docs.wire.com/how-to/install/ansible-VMs.html

### updates to the inventory

make sure your inventory sets:

# Explicitely specify the restund user id to be "root" to override the default of "997"
restund_uid = root

[minio:vars]
minio_deeplink_prefix = domainname.com
minio_deeplink_domain = prefix-

# move the kubeconfig

old versions of the package contained the kubeconfig at ansible/kubeconfig.

mkdir ansible/inventory/offline/artifacts
cp ansible/kubeconfig ansible/inventory/offline/artifacts/admin.conf


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

## Upgrading stateful services

With docker being installed on all nodes that need it, seed all container images:

```
d ansible-playbook -i ./ansible/inventory/offline ansible/seed-offline-docker.yml
```

Ensure the cluster comes is healthy. The container also contains kubectl, so check the node status:

```
d kubectl get nodes -owide
```
They should all report ready.

## Deploying wire-server using helm

It's now time to upgrade the helm charts on top of kubernetes, upgrading the Wire platform.

inspect your values and secrets files, comparing them to the new defaults.

Now deploy `wire-server`:

```
d helm install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```

### Upgradinging sftd

For full docs with details and explanations please see https://github.com/wireapp/wire-server-deploy/blob/d7a089c1563089d9842aa0e6be4a99f6340985f2/charts/sftd/README.md

First, make sure you still have the certificates for `sftd.<yourdomain>`. This could be the same wildcard or SAN certificate you used at previous steps.

If you are restricting SFT to certain nodes, make sure that in your inventory
you have annotated all the nodes that are able to run sftd workloads correctly.
```
kubenode3 node_labels="{'wire.com/role': 'sftd'}" node_annotations="{'wire.com/external-ip': 'XXXX'}"
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
