# How to upgrade wire (services only)

We have a pipeline in `wire-server-deploy` producing container images, static binaries, ansible playbooks, debian package sources and everything required to install Wire.

Create a fresh workspace to download the new artifacts:

```
$ cd ...  # you pick a good location!
```

Obtain the latest airgrap artifact for wire-server-deploy. Please contact us to get it for now. We are
working on publishing a list of airgap artifacts.

## Clean up enough disk space to operate:

### AdminHost
Prune old containers that are generated during our 'd' invocations:
```
df -h
sudo docker container prune
```

Prune old security update deployment archives:
```
sudo apt clean
```

### Kubernetes hosts:

#### Wire
Remove wire-server images from two releases ago, or from the current release that we know are unused. For instance, 

```
sudo docker image ls
VERSION="2.106.0"
sudo docker image ls | grep -E "^quay.io/wire/" | grep $VERSION | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"

```

If you are not running SFT in your main cluster (for example, do not use SFT, or have SFT in a separate DMZ'd cluster).. then remove SFT images from the Wire Kubernetes.
```
sudo docker image ls | grep -E "^quay.io/wire/sftd" | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"
```

#### SFT
If you are running a DMZ deployment, prune the old wire-server images and their dependencies on the SFT kubernetes hosts...
```
sudo docker image ls | grep -E "^quay.io/wire/(team-settings|account|webapp|namshi-smtp)" | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"
sudo docker image ls | grep -E "^(bitnami/redis|airdock/fake-sqs|localstack/localstack)" | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"
sudo docker image rm 
```

## Preparing for deployment
Verify you have the container images and configuration for the version of wire you are currently running.

Extract the latest airgap artifact into your workspace:

```
$ wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-<HASH>.tgz
$ tar xvzf wire-server-deploy-static-<HASH>.tgz
```
Where the HASH above is the hash of your deployment artifact, given to you by Wire, or acquired by looking at the above build job.
Extract this tarball.

There's also a docker image containing the tooling inside this repo.

Source the following shell script.
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

The following is a list of important artifacts which are provided:

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

Copy `ansible/inventory/offline/99-static` to `ansible/inventory/offline/hosts.ini`.

Compare the inventory from your old install to the inventory of your new install.

Here you will describe the topology of your offline deploy. There are instructions in the comments on how to set
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

old versions of the package contained the kubeconfig at ansible/kubeconfig. newer ones create a directory at ansible/inventory/offline/artifacts, and place the kubeconfig there, as 'admin.conf'

If your deployment package uses the old style, then in the place where you are keeping your new package:
```
mkdir ansible/inventory/offline/artifacts
cp ../<OLD_PACKAGE_DIR/ansible/kubeconfig ansible/inventory/offline/artifacts/admin.conf
```

otherwise:
```
mkdir ansible/inventory/offline/artifacts
sudo cp ../<OLD_PACKAGE_DIR>/ansible/inventory/offline/artifacts/admin.conf ansible/inventory/offline/artifacts/admin.conf
```

## Preparing to upgrade kubernetes services

log into the assethost, and verify the 'serve-assets' systemd component is running by looking at netstat -an, and checking for `8080`. If it's not:
```
sudo service serve-assets start
```

Since docker is already installed on all nodes that need it, push the new container images to the assethost, and seed all container images:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/setup-offline-sources.yml --tags "containers-helm"
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/seed-offline-docker.yml
```

Ensure the cluster is healthy. use kubectl to check the node health:

```
d kubectl get nodes -owide
```
They should all report ready.

## Upgrading wire-server using helm

### Upgrading non-wire components:

#### External Service Definitions:

Compare your external service definition files, and decide whether you need to change them or not.
```
diff -u ../<OLD_PACKAGE_DIR>/values/cassandra-external/values.yaml values/cassandra-external/prod-values.example.yaml
diff -u ../<OLD_PACKAGE_DIR>/values/elasticsearch-external/values.yaml values/elasticsearch-external/prod-values.example.yaml
diff -u ../<OLD_PACKAGE_DIR>/values/minio-external/values.yaml values/minio-external/prod-values.example.yaml
```

If there are only IP addresses in the diff output, copy these files into your new tree.
```
cp ../<OLD_PACKAGE_DIR>/values/cassandra-external/values.yaml values/cassandra-external/values.yaml
cp ../<OLD_PACKAGE_DIR>/values/elasticsearch-external/values.yaml values/elasticsearch-external/values.yaml
cp ../<OLD_PACKAGE_DIR>/values/minio-external/values.yaml values/minio-external/values.yaml
```

If not, examine differences between the values files for the old service definitions and the new service definitions

When you are satisfied with the results of the above, upgrade the external service definitions.
```
d helm upgrade cassandra-external ./charts/cassandra-external/ --values ./values/cassandra-external/values.yaml
d helm upgrade elasticsearch-external ./charts/elasticsearch-external/ --values ./values/elasticsearch-external/values.yaml
d helm upgrade minio-external ./charts/minio-external/ --values ./values/minio-external/values.yaml
```

#### Non-Wire Services

Compare your non-wire service definition files, and decide whether you need to change them or not.
```
diff -u ../<OLD_PACKAGE_DIR>/values/fake-aws/prod-values.example.yaml values/cassandra-external/prod-values.example.yaml
diff -u ../<OLD_PACKAGE_DIR>/values/databases-ephemeral/values.yaml values/databases-ephemeral/prod-values.example.yaml
```

If there are no differences, copy these files into your new tree.
```
cp ../<OLD_PACKAGE_DIR>/values/fake-aws/prod-values.example.yaml values/cassandra-external/values.yaml
cp ../<OLD_PACKAGE_DIR>/values/databases-ephemeral/values.yaml values/databases-ephemeral/values.yaml
```

Next, upgrade the internal non-wire services.
```
d helm upgrade fake-aws ./charts/fake-aws/ --values ./values/fake-aws/values.yaml
d helm upgrade databases-ephemeral ./charts/databases-ephemeral/ --values ./values/databases-ephemeral/values.yaml
d helm upgrade reaper ./charts/reaper/
```

#### Demo-SMTP service

Compare your demo-smtp configuration files, and decide whether you need to change them or not.
```
diff -u ../<OLD_PACKAGE_DIR>/values/demo-smtp/values.yaml values/demo-smtp/values.yaml
```

If there are no differences, copy these files into your new tree.
```
cp ../<OLD_PACKAGE_DIR>/values/demo-smtp/values.yaml values/demo-smtp/values.yaml
```

```
d helm upgrade demo-smtp ./charts/demo-smtp/ --values ./values/demo-smtp/values.yaml
```

#### Upgrading the NginX Ingress

Compare your demo-smtp configuration files, and decide whether you need to change them or not.
```
diff -u ../<OLD_PACKAGE_DIR>/values/ngin-ingress-services/values.yaml values/nginx-ingress-services/prod-values.example.yaml
```

If there are no differences, copy these files into your new tree.
```
cp ../<OLD_PACKAGE_DIR>/values/nginx-ingress-services/values.yaml values/nginx-ingress-services/values.yaml
```

d helm upgrade nginx-ingress-controller ./charts/nginx-ingress-controller/
d helm upgrade nginx-ingress-services ./charts/nginx-ingress-services/ --values ./values/nginx-ingress-services/values.yaml  --values ./values/nginx-ingress-services/secrets.yaml
```

### Upgrading Wire itsself

Inspect your `values.yaml` and `secrets.yaml` files with diff comparing them to the new defaults.

Now upgrade `wire-server`:

```
d helm upgrade wire-server ./charts/wire-server/ --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```

### Marking kubenode for calling server (SFT)

The SFT Calling server should be running on a kubernetes nodes that are connected to the public internet.
If not all kubernetes nodes match these criteria, you should specifically label the nodes that do match
these criteria, so that we're sure SFT is deployed correctly.


By using a `node_label` we can make sure SFT is only deployed on a certain node like `kubenode4`

```
kubenode4 node_labels="wire.com/role=sftd" node_annotations="{'wire.com/external-ip': 'XXXX'}"
```

If the node does not know its own public IP (e.g. because it's behind NAT) then you should also set
the `wire.com/external-ip` annotation to the public IP of the node.

### Upgradinging sftd

For full docs with details and explanations please see https://github.com/wireapp/wire-server-deploy/blob/d7a089c1563089d9842aa0e6be4a99f6340985f2/charts/sftd/README.md

First, make sure you still have the certificates for `sftd.<yourdomain>`. This could be the same wildcard or SAN certificate you used at previous steps.

If you are restricting SFT to certain nodes, make sure that in your inventory
you have annotated all the nodes that are able to run sftd workloads correctly.
```
kubenode3 node_labels="{'wire.com/role': 'sftd'}" node_annotations="{'wire.com/external-ip': 'XXXX'}"
```

You may also want to look at the output of `d kubectl describe node` for each node, and to see if the node label, attribute and annotations are in order.

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
