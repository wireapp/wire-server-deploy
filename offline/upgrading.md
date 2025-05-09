# How to upgrade wire (services only)

We have a pipeline in `wire-server-deploy` producing container images, static binaries, ansible playbooks, debian package sources and everything required to install Wire.

Create a fresh workspace to download the new artifacts:

```
$ mkdir ... # you pick a good location!
$ cd ...
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

#### Wire Cluster

Remove wire-server images from two releases ago, or from the current release that we know are unused. For instance,

```
sudo docker image ls
# look at the output of the last command, to find
VERSION="2.106.0"
sudo docker image ls | grep -E "^quay.io/wire/([bcg]|spar|nginz)" | grep $VERSION | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"
```

If you are not running SFT in your main cluster (for example, do not use SFT, or have SFT in a separate DMZ'd cluster).. then remove SFT images from the Wire Kubernetes cluster.

```
sudo docker image ls | grep -E "^quay.io/wire/sftd" | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"
```

For newer versions of wire-server (post 4.20.0) use `crictl` instead of docker. For example:

```
sudo crictl image ls
# look at the output of the last command, to find
VERSION="4.20.0"
sudo crictl image ls | grep -E "^quay.io/wire/([bcg]|spar|nginz)" | grep $VERSION | sed "s/.*[ ]*\([0-9a-f]\{13\}\).*/sudo crictl rmi \1/"
```

#### SFT Cluster

If you are running a DMZ deployment, prune the old wire-server images and their dependencies on the SFT kubernetes hosts...

```
sudo docker image ls | grep -E "^quay.io/wire/(team-settings|account|webapp|ixdotai-smtp)" | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"
sudo docker image ls | grep -E "^(bitnami/redis|airdock/fake-sqs|localstack/localstack)" | sed "s/.*[ ]*\([0-9a-f]\{12\}\).*/sudo docker image rm \1/"
```

For newer versions of wire-server (post 4.20.0) use `crictl image ls` and `crictl rmi` instead of docker commands, like in previous example.

## Preparing for deployment

Verify you have the container images and configuration for the version of wire you are currently running.

Extract the latest airgap artifact into a NEW workspace:

```
$ wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-<HASH>.tgz
$ mkdir New-Wire-Server
$ cd New-Wire-Server
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
- `debs-*.tar`
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

Diff outputs differences between the two files. lines that start with `@@` specify a position. lines with `-` are from the old file, lines with `+` are from the new inventory, and lines starting with ` ` are the same in both files. We are going to use diff to compare files from your old install with your new install.

Copy `ansible/inventory/offline/99-static` to `ansible/inventory/offline/hosts.ini`.

Compare the inventory from your old install to the inventory of your new install.

```
diff -u ../<OLD_PACKAGE_DIR>/ansible/inventory/offline/99-static ansible/inventory/offline/hosts.ini
```

Your old install may use a `hosts.ini` instead of `99-static`.
check to see if a hosts.ini is present:

```
ls ../<OLD_PACKAGE_DIR>/ansible/inventory/offline/hosts.ini
```

If you get "cannot access ..... No such file or directory", compare the 99-static from the old install.

```
diff -u ../<OLD_PACKAGE_DIR>/ansible/inventory/offline/99-static ansible/inventory/offline/hosts.ini
```

otherwise, compare hosts.ini from both installation directories.

```
diff -u ../<OLD_PACKAGE_DIR>/ansible/inventory/offline/hosts.ini ansible/inventory/offline/hosts.ini
```

Using a text editor, make sure your new hosts.ini has all of the work you did on the first installation.

There are instructions in the comments on how to set everything up. You can also refer to extra information at https://docs.wire.com/how-to/install/ansible-VMs.html .

### TURN (legacy)

If you are installing one of the newer artifacts (5.0.0) we recommend migrating to coturn if you haven't already. https://github.com/wireapp/wire-server-deploy/blob/master/offline/coturn.md

If you are using restund calling services, make sure your inventory sets:

```
# Explicitely specify the restund user id to be "root" to override the default of "997"
restund_uid = root
```

### Deeplink

If you are using the old deeplink process (deprecated!), set:

```
[minio:vars]
minio_deeplink_prefix = domainname.com
minio_deeplink_domain = prefix-
```

### SFT

If you have SFT on the same cluster as your wire cluster, read the `Marking kubenode for calling server (SFT)` section below.

# Migrate the kubeconfig

Old versions of the package contained the kubeconfig at ansible/kubeconfig. newer ones create a directory at ansible/inventory/offline/artifacts, and place the kubeconfig there, as 'admin.conf'

If your deployment package uses the old style, then in the place where you are keeping your new package:

```
mkdir ansible/inventory/offline/artifacts
cp ../<OLD_PACKAGE_DIR>/ansible/kubeconfig ansible/inventory/offline/artifacts/admin.conf
```

Otherwise:

```
mkdir ansible/inventory/offline/artifacts
sudo cp ../<OLD_PACKAGE_DIR>/ansible/inventory/offline/artifacts/admin.conf ansible/inventory/offline/artifacts/admin.conf
```

## Preparing to upgrade kubernetes services

Log into the assethost, and verify the 'serve-assets' systemd component is running by looking at `sudo lsof -i -P -n | grep LISTEN`, and checking for `8080`. If it's not:

```
sudo service serve-assets start
```

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

- find a big block of comments and uncomment everything in it `- name: trust everything...`
- after the block you will find `- name: Register offline repo key...`. Comment out that segment (do not comment out the part with `- name: Register offline repo`!)

If you are doing anything with kubernetes itsself (unlikely!), disable checking for outdated signatures by editing the following file:

```
ansible/roles/external/kubespray/roles/container-engine/docker/tasks/main.yml
```

- comment out the block with -name: ensure docker-ce repository public key is installed...
- comment out the next block -name: ensure docker-ce repository is enabled

Now you are ready to start deploying services.

#### WORKAROUND: dependency

some ubuntu systems do not have GPG by default. wire assumes this is already present. ensure you have gpg installed on all of your nodes before continuing to the next step.

#### Populate the assethost, and prepare to install images from it.

If you think you might run into storage issues. Remove the `/opt/assets/` directory as we will copy over new ones in the following steps.

Since docker is already installed on all nodes that need it, push the new container images to the assethost, and seed all container images:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/setup-offline-sources.yml
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/seed-offline-docker.yml
```

If you are using newer version of wire-server (post 4.20)

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/seed-offline-containerd.yml
```

#### Ensuring kubernetes is healthy.

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
diff -u ../<OLD_PACKAGE_DIR>/values/rabbitmq-external/values.yaml values/rabbitmq-external/prod-values.example.yaml
```

If there are only IP addresses in the diff output, copy these files into your new tree.

```
cp ../<OLD_PACKAGE_DIR>/values/cassandra-external/values.yaml values/cassandra-external/values.yaml
cp ../<OLD_PACKAGE_DIR>/values/elasticsearch-external/values.yaml values/elasticsearch-external/values.yaml
cp ../<OLD_PACKAGE_DIR>/values/minio-external/values.yaml values/minio-external/values.yaml
cp ../<OLD_PACKAGE_DIR>/values/rabbitmq-external/values.yaml values/rabbitmq-external/values.yaml
```

If not, examine differences between the values files for the old service definitions and the new service definitions

When you are satisfied with the results of the above, upgrade the external service definitions.

```
d helm upgrade cassandra-external ./charts/cassandra-external/ --values ./values/cassandra-external/values.yaml
d helm upgrade elasticsearch-external ./charts/elasticsearch-external/ --values ./values/elasticsearch-external/values.yaml
d helm upgrade minio-external ./charts/minio-external/ --values ./values/minio-external/values.yaml
d helm upgrade rabbitmq-external ./charts/rabbitmq-external/ --values ./values/rabbitmq-external/values.yaml
```

#### Non-Wire Services

Compare your non-wire service definition files, and decide whether you need to change them or not.

```
diff -u ../<OLD_PACKAGE_DIR>/values/fake-aws/prod-values.example.yaml values/fake-aws/prod-values.example.yaml
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

#### Upgrading the demo SMTP service

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

#### Upgrading the NginX ingress

Compare your demo-smtp configuration files, and decide whether you need to change them or not.

```
diff -u ../<OLD_PACKAGE_DIR>/values/nginx-ingress-services/values.yaml values/nginx-ingress-services/prod-values.example.yaml
```

If there are no differences, copy these files into your new tree.

```
cp ../<OLD_PACKAGE_DIR>/values/nginx-ingress-services/values.yaml values/nginx-ingress-services/values.yaml
```

#### Upgrading ingress-nginx-controller

Re-deploy your ingress, to direct traffic into your cluster with the new version of nginx.

```
d helm upgrade ingress-nginx-controller ./charts/ingress-nginx-controller/
```

### Upgrading Wire itsself

Inspect your `values.yaml` and `secrets.yaml` files with diff comparing them to the new defaults.

```
diff -u ../<OLD_PACKAGE_DIR>/values/wire-server/prod-secrets-example.yaml values/wire-server/prod-secrets-example.yaml
diff -u ../<OLD_PACKAGE_DIR>/values/wire-server/prod-values-example.yaml values/wire-server/prod-values-example.yaml
```

#### IMPORTANT (for wire-server older than 4.38)

Some wire-server charts (`webapp`, `team-settings`, `account-pages`), who were previously being installed alongside wire-server are now being shipped standalone. To avoid potential issues, please uninstall `wire-server` deployment first!

```
d helm uninstall wire-server
```

Now upgrade/reinstall `wire-server`:

```
d helm upgrade --install wire-server ./charts/wire-server/ --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```

#### Webapp

To compare with previous values you will have to check in your `values/wire-server/values.yaml` and compare the `webapp` section with `values/webapp/values.yaml`.

To upgrade:

```
d helm upgrade --install webapp charts/webapp -f values/webapp/values.yaml
```

#### Team-settings

To compare with previous values you will have to check in your `values/wire-server/values.yaml` and compare the `team-settings` section with `values/team-settings/values.yaml`.

To upgrade:

```
d helm upgrade --install team-settings charts/team-settings -f values/team-settings/values.yaml -f values/team-settings/secrets.yaml
```

#### Account-pages

To compare with previous values you will have to check in your `values/wire-server/values.yaml` and compare the `account-pages` section with `values/account-pages/values.yaml`.

To upgrade:

```
d helm upgrade --install account-pages charts/account-pages -f values/account-pages/values.yaml
```

#### Bring your own certificates

If you generated your own SSL certificates, there are two ways to give these to wire:

##### From the command line

if you have the certificate and it's corresponding key available on the filesystem, copy them into the root of the Wire-Server directory, and:

```
d helm install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml --set-file secrets.tlsWildcardCert=certificate.pem --set-file secrets.tlsWildcardKey=key.pem
```

Do not try to use paths to refer to the certificates, as the 'd' command messes with file paths outside of Wire-Server.

##### In your nginx config

This is the more error prone process, due to having to edit yaml files.

Change the domains in `values.yaml` to your domain. And add your wildcard or SAN certificate that is valid for all these
domains to the `secrets.yaml` file.

Now install the service with helm:

```
d helm install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml --values ./values/nginx-ingress-services/secrets.yaml
```

#### Use letsencrypt generated certificates

UNDER CONSTRUCTION:
If your machine has internet access to letsencrypt's servers, you can configure cert-manager to generate certificates, and load them for you.

```
d kubectl create namespace cert-manager-ns
d helm upgrade --install -n cert-manager-ns --set 'installCRDs=true' cert-manager charts/cert-manager
d helm upgrade --install nginx-ingress-services charts/nginx-ingress-services -f values/nginx-ingress-services/values.yaml
```

### Marking kubenode for calling server (SFT)

The SFT Calling server should be running on a set of kubernetes nodes that have traffic directed to them from the public internet.
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
