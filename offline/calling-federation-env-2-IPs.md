# Setting up a federated calling environment with two IP addresses

## Intro

Documentation details how to set up a Kubernetes cluster with only SFTD and Restund calling services configured for federation via Helm charts. Prior experience with setting up a [KVM Hetzner](https://github.com/wireapp/wire-server-deploy/blob/master/offline/ubuntu22.04_installation.md) and a [Wire-in-a-Box environment](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md) is presumed.

Requirements:

- KVM Hetzner environment with 4 VMs (assethost, kubenode1, kubenode2, kubenode3)
- wire-server-deploy artifact
- sftd version: 4.0.6 or newer
- [Restund Helm chart](https://github.com/wireapp/wire-server/tree/develop/charts/restund)

SFTD will be deployed on the main IP (main eth interface) and Restund on the secondary.

## Setting up secondary interface and macvlan

Request a second MAC address and IP from Hetzner for your machine.

Set up the secondary interface with:

```
sudo ip link add link <main_interface> address <MAC_address> <new_interface_name> type macvlan
```

Assign IP address:

```
sudo ip addr add <ip_address>/<subnet_mask> dev <new_interface_name>
```

Add a gateway:

```
sudo ip route add via <gateway_ip> dev <new_interface_name>
```

Activate the interface:

```
sudo ip link set dev <new_interface_name> up
```

## Installing docker

On your machine (further "adminhost"), you need `docker`
installed (or any other compatible container runtime really, even though
instructions may need to be modified). See [how to install
docker](https://docker.com) for instructions.

On ubuntu 22.04, connected to the internet:

```
sudo apt install docker.io
sudo systemctl enable docker
sudo systemctl start docker
```

Ensure the user you are using for the install has permission to run docker, or add 'sudo' to the docker commands below.

### Ensuring you can run docker without sudo:

Run the following command to add your user to the docker group:

```
sudo usermod -aG docker $USER
```

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

Where `<HASH>` above is the hash of your deployment artifact, given to you by Wire, or acquired by looking at the above build job.
Extract this tarball.

Make sure that the admin host can `ssh` into all the machines that you want to provision. Our docker container will use the `.ssh` folder and the `ssh-agent` of the user running the scripts.

There's also a docker image containing the tooling inside this repo.

## Making tooling available in your environment.

Source the following shell script:

```
source ./bin/offline-env.sh
```

The shell script will set up a `d` alias. Which runs commands passed to it inside the docker container
with all the tools needed for doing an offline deploy.

## Editing the inventory

Copy `ansible/inventory/offline/99-static` to `ansible/inventory/offline/hosts.ini`

```
cp ansible/inventory/offline/99-static ansible/inventory/offline/hosts.ini
mv ansible/inventory/offline/99-static ansible/inventory/offline/orig.99-static
```

Edit `ansible/inventory/offline/hosts.ini`. Here, you will describe the topology of your offline deploy.

##### Adding host entries

when editing the inventory, we need four entries in the '[all]' section. One entry for each of the VMs we are running.
Edit the 'kubenode' entries and the 'assethost' entry.

Eg.

```
[all]
kubenode1 ansible_host=172.16.0.129
kubenode2 ansible_host=172.16.0.130
kubenode3 ansible_host=172.16.0.131
# Further down you will find assethost entry
assethost ansible_host=172.16.0.128
```

If you are using username/password to log into and sudo up, in the `all:vars` section, add:

```
ansible_user=<USERNAME>
ansible_password=<PASSWORD>
ansible_become_pass=<PASSWORD>
```

Add one of the kubenode entries into the `restund` section

```
[restund:vars]
# Uncomment if your public IP is not on the default gateway
restund_network_interface = enp34s0.1 # set this to your network adapter name has the restund public IP
# Uncomment and set to the true public IP if you are behind 1:1 NAT
restund_peer_udp_advertise_addr = your.public.ip.address
[restund]
kubenode1
```

### Configuring kubernetes and etcd

You'll need at least 3 `kubenode`s. 3 of them should be added to the
`[kube-master]`, `[etcd]` and `[kube-node]` groups of the inventory file. Any
additional nodes should only be added to the `[kube-node]` group.

```
# Add all nodes that should be the master
[kube-master]
kubenode1
kubenode2
kubenode3

[etcd]
# !!! There MUST be an UNEVEN amount of etcd servers
#
# Uncomment if etcd and kubernetes are colocated
#
kubenode1 etcd_member_name=etcd1
kubenode2 etcd_member_name=etcd2
kubenode3 etcd_member_name=etcd3
#
# Uncomment if etcd cluster is separately deployed from kubernetes masters
# etcd1 etcd_member_name=etcd1
# etcd2 etcd_member_name=etcd2
# etcd3 etcd_member_name=etcd3

# Add all worker nodes here
[kube-node]
kubenode1
kubenode2
kubenode3

# Additional worker nodes can be added
# You can label and annotate nodes. E.g. when deploying SFT you might want to
# deploy it only on certain nodes due to the public IP requirement.
# kubenode4 node_labels="{'wire.com/role': 'sftd'}" node_annotations="{'wire.com/external-ip': 'XXXX'}"
# kubenode5 node_labels="{'wire.com/role': 'sftd'}" node_annotations="{'wire.com/external-ip': 'XXXX'}"

# leave this group as is
[k8s-cluster:children]
kube-master
kube-node
```

## Generating secrets

Minio and restund services have shared secrets with the `wire-server` helm chart. We have a utility
script that generates a fresh set of secrets for these components.

Please run:

```
./bin/offline-secrets.sh
```

This should generate two files. `./ansible/inventory/group_vars/all/secrets.yaml` and `values/wire-server/secrets.yaml`.

Copy the value of secret under 'turn' section. You will need it to configure restund and sftd later.

```
turn:
  secret: "some-hash"
```

## Expired debian key

[WORKAROUND](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#workaround-old-debian-key)

## Deploying with Ansible

### Populate the assethost, and prepare to install images from it.

Copy over binaries and debs, serves assets from the asset host, and configure
other hosts to fetch debs from it:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/setup-offline-sources.yml
```

If this step fails partway, and you know that parts of it completed, the `--skip-tags debs,binaries,containers,containers-helm,containers-other` tags may come in handy.

#### Add newer sftd image to assethost

At the time of writing. No artifact has sftd v4.0.6 (or higher) packaged. So it will have to be pulled from quay.io manually and assethost resources will have to be mutated.

Pull the image from Quay:

```
docker pull quay.io/wire/sftd:4.0.6
```

Save the image in tar format:

```
docker save -o quay.io_wire_sftd_4.0.6.tar quay.io/wire/sftd:4.0.6
```

Copy it to your assethost:

```
scp quay.io_wire_sftd_4.0.6.tar demo@assethost:/home/demo/
```

Move it to /opt/assets/containers-helm dir:

```
sudo mv quay.io_wire_sftd_4.0.6.tar /opt/assets/containers-helm/
```

Edit the index.txt in there and either change the current sftd entry (ie. quay.io_wire_sftd_2.1.19.tar) to match your current version or just add it to the list. Save your changes.

### Kubernetes, part 1

Run kubespray until docker is installed and runs. This allows us to preseed the docker containers that
are part of the offline bundle:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine
```

### Pushing container images to kubenodes, restund nodes and load them into containerd.

With ctr being installed on all nodes that need it, seed all container images:

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/seed-offline-containerd.yml
```

### Kubernetes, part 2

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

## Deploying with Helm

### Deploy ingress-nginx-controller

This component requires no configuration, and is a requirement for all of the methods we support for getting traffic into your cluster:

```
mv ./values/ingress-nginx-controller/prod-values.example.yaml ./values/ingress-nginx-controller/values.yaml
d helm install ingress-nginx-controller ./charts/ingress-nginx-controller --values ./values/ingress-nginx-controller/values.yaml
```

### Forwarding traffic to your cluster

Check the ethernet interface name for your outbound IP.

```
ip ro | sed -n "/default/s/.* dev \([enpso0-9]*\) .*/export OUTBOUNDINTERFACE=\1/p"
```

This will return a shell command setting a variable to your default interface. copy and paste it into shell.

Supply your outside IP address (main one from main eth interface):

```
export PUBLICIPADDRESS=<your.ip.address.here>
```

1. Run `d kubectl get pods -o wide`
2. See on which node `ingress-nginx` is running
3. Get the IP of this node by running `ip address` on that node
4. Use that IP for $KUBENODEIP

```
export KUBENODEIP=<your.kubernetes.node.ip>
```

then run the following:

```
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $KUBENODEIP:31772
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 443 -j DNAT --to-destination $KUBENODEIP:31773
```

If you are running a UFW firewall, make sure to allow inbound traffic on 443 and 80:

```
sudo ufw enable
sudo ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 443
sudo ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 80
```

###### Mirroring the public IP

cert-manager has a requirement on being able to reach the kubernetes on it's external IP. this is trouble, because in most security concious environments, the external IP is not owned by any of the kubernetes hosts.

on an IP Masquerading router, you can redirect outgoing traffic from your cluster, that is to say, when the cluster asks to connect to your external IP, you can instead choose to send it to a kubernetes node inside of the cluster.

```
export INTERNALINTERFACE=br0
sudo iptables -t nat -A PREROUTING -i $INTERNALINTERFACE -d $PUBLICIPADDRESS -p tcp --dport 80 -j DNAT --to-destination $KUBENODEIP:31772
sudo iptables -t nat -A PREROUTING -i $INTERNALINTERFACE -d $PUBLICIPADDRESS -p tcp --dport 443 -j DNAT --to-destination $KUBENODEIP:31773
```

### Acquiring / Deploying SSL Certificates:

SSL certificates are required by the nginx-ingress-services helm chart. You can either register and provide your own, or use cert-manager to request certificates from LetsEncrypt. Here we will use LetsEncrypt and cert-manager

#### Use letsencrypt generated certificates

If you are using a single external IP and no route than you need to make sure that the cert-manger pods are not deployed on the same node as ingress-nginx-controller node.

To do that...check where ingress-nginx-controller pod is running on -

```
d kubectl get pods -o wide
```

For e.g. .. if it is kubenode1

than taint the kubenode1:

```
d kubectl cordon kubenode1
```

First, download cert manager, and place it in the appropriate location:

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

Create a new namespace for cert-manager and deploy it. Install CRDs with it as it will be required for nginx-ingress-services chart.

```
d kubectl create namespace cert-manager-ns
d helm upgrade --install -n cert-manager-ns --set 'installCRDs=true' cert-manager charts/cert-manager
```

Uncordon the node you cordoned earlier:

```
d kubectl uncordon kubenode1
```

##### Prepare to deploy nginx-ingress-services

Edit values/nginx-ingress-services/values.yaml , to tell ingress-ingress-services to use cert-manager:

- set useCertManager: true
- set certmasterEmail: your.email.address

Set your domain name with sed:

```
sed -i "s/example.com/YOURDOMAINHERE/" values/nginx-ingress-services/values.yaml
```

Then run:

```
d helm install nginx-ingress-services charts/nginx-ingress-services -f values/nginx-ingress-services/values.yaml
```

Watch the output of the following command to know how your request is going:

```
d kubectl get certificate
```

### Restund

Download [Restund Helm chart](https://github.com/wireapp/wire-server/tree/develop/charts/restund) and copy it to your adminhost. Move it into `charts/` directory.

Create a values file for restund chart or modify the existing one in the charts:

```
nano values/restund/values.yaml

secrets:
  zrestSecret: "hash" # use the hash value you got from generating secrets here
federate:
  enabled: true # enable federation
  dtls:
    tls:
      certificate:
        labels:
        dnsNames:
           - restund.your.domain
      issuerRef:
        kind: Issuer
        name: letsencrypt-http01
        group: cert-manager.io
    # CA certificate of letsencrypt. Yes, it is required, and you are welcome. Mind the spacing
    ca: |
      "-----BEGIN CERTIFICATE-----
      MIIFFjCCAv6gAwIBAgIRAJErCErPDBinU/bWLiWnX1owDQYJKoZIhvcNAQELBQAw
      TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
      cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMjAwOTA0MDAwMDAw
      WhcNMjUwOTE1MTYwMDAwWjAyMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNTGV0J3Mg
      RW5jcnlwdDELMAkGA1UEAxMCUjMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
      AoIBAQC7AhUozPaglNMPEuyNVZLD+ILxmaZ6QoinXSaqtSu5xUyxr45r+XXIo9cP
      R5QUVTVXjJ6oojkZ9YI8QqlObvU7wy7bjcCwXPNZOOftz2nwWgsbvsCUJCWH+jdx
      sxPnHKzhm+/b5DtFUkWWqcFTzjTIUu61ru2P3mBw4qVUq7ZtDpelQDRrK9O8Zutm
      NHz6a4uPVymZ+DAXXbpyb/uBxa3Shlg9F8fnCbvxK/eG3MHacV3URuPMrSXBiLxg
      Z3Vms/EY96Jc5lP/Ooi2R6X/ExjqmAl3P51T+c8B5fWmcBcUr2Ok/5mzk53cU6cG
      /kiFHaFpriV1uxPMUgP17VGhi9sVAgMBAAGjggEIMIIBBDAOBgNVHQ8BAf8EBAMC
      AYYwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMBMBIGA1UdEwEB/wQIMAYB
      Af8CAQAwHQYDVR0OBBYEFBQusxe3WFbLrlAJQOYfr52LFMLGMB8GA1UdIwQYMBaA
      FHm0WeZ7tuXkAXOACIjIGlj26ZtuMDIGCCsGAQUFBwEBBCYwJDAiBggrBgEFBQcw
      AoYWaHR0cDovL3gxLmkubGVuY3Iub3JnLzAnBgNVHR8EIDAeMBygGqAYhhZodHRw
      Oi8veDEuYy5sZW5jci5vcmcvMCIGA1UdIAQbMBkwCAYGZ4EMAQIBMA0GCysGAQQB
      gt8TAQEBMA0GCSqGSIb3DQEBCwUAA4ICAQCFyk5HPqP3hUSFvNVneLKYY611TR6W
      PTNlclQtgaDqw+34IL9fzLdwALduO/ZelN7kIJ+m74uyA+eitRY8kc607TkC53wl
      ikfmZW4/RvTZ8M6UK+5UzhK8jCdLuMGYL6KvzXGRSgi3yLgjewQtCPkIVz6D2QQz
      CkcheAmCJ8MqyJu5zlzyZMjAvnnAT45tRAxekrsu94sQ4egdRCnbWSDtY7kh+BIm
      lJNXoB1lBMEKIq4QDUOXoRgffuDghje1WrG9ML+Hbisq/yFOGwXD9RiX8F6sw6W4
      avAuvDszue5L3sz85K+EC4Y/wFVDNvZo4TYXao6Z0f+lQKc0t8DQYzk1OXVu8rp2
      yJMC6alLbBfODALZvYH7n7do1AZls4I9d1P4jnkDrQoxB3UqQ9hVl3LEKQ73xF1O
      yK5GhDDX8oVfGKF5u+decIsH4YaTw7mP3GFxJSqv3+0lUFJoi5Lc5da149p90Ids
      hCExroL1+7mryIkXPeFM5TgO9r0rvZaBFOvV2z0gp35Z0+L4WPlbuEjN/lxPFin+
      HlUjr8gRsI3qfJOQFy/9rKIJR0Y/8Omwt/8oTWgy1mdeHmmjk7j1nYsvC9JSQ6Zv
      MldlTTKB3zhThV1+XWYp6rjd5JW1zbVWEkLNxE7GJThEUG3szgBVGP7pSWTUTsqX
      nLRbwHOoq7hHwg==
      -----END CERTIFICATE-----
      -----BEGIN CERTIFICATE-----
      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
      -----END CERTIFICATE-----"
```

Reconfigure Restund configmap in restund chart `charts/restund/templates/configmap-restund-conf-template.yaml`

```
    udp_listen              ${POD_IP}:{{ .Values.restundUDPListenPort }} # change RESTUND_HOST into POD_IP

    tcp_listen              ${POD_IP}:{{ .Values.restundTCPListenPort }} # change RESTUND_HOST into POD_IP

    # federate
    federate_listen         ${POD_IP} # change RESTUND_HOST into POD_IP
```

Before deploying you should taint the node ingress-nginx-controller is on to repel Restund from it:

```
d kubectl taint nodes <node_name> wire.com/role=restund:NoExecute
d kubectl taint nodes <node_name> wire.com/role=restund:NoSchedule
```

You should also make it aware of its external IP with annotation:

```
d kubectl annotate node <node_name> wire.com/external-ip=your.secondary.ip.address
```

Now deploy Restund with:

```
d helm install restund charts/restund --values values/restund/values.yaml
```

Pray you didn't mess up the spacing as yaml is a cruel mistress.

#### Forwarding traffic

```
export SECONDARYINTERFACE=<new_interface_name>
export SECONDARYIPADDRESS=<your.secondary.ip.address>
export RESTUNDINTERNALIP=<node.where.restund.is>

sudo iptables -t nat -A PREROUTING -d $SECONDARYIPADDRESS -i $SECONDARYINTERFACE -p tcp --dport 80 -j DNAT --to-destination $RESTUNDINTERNALIP:80
sudo iptables -t nat -A PREROUTING -d $SECONDARYIPADDRESS -i $SECONDARYINTERFACE -p udp --dport 80 -j DNAT --to-destination $RESTUNDINTERNALIP:80
sudo iptables -t nat -A PREROUTING -d $SECONDARYIPADDRESS -i $SECONDARYINTERFACE -p udp -m udp --dport 32768:60999 -j DNAT --to-destination $RESTUNDINTERNALIP
```

### SFTD

Modify `Chart.yaml` of SFTD chart, change appVersion value to match your sftd image you provided (in this documentation 4.0.6). This step might be redundant in the future.

Edit `values/sftd/values.yaml`

```
host: sftd.your.domain
tls:
  issuerRef:
    name: letsencrypt-http01
# also add the following lines
multiSFT:
  enabled: true
  discoveryRequired: false
  secret: "hash" # same secret you used in restund chart
  turnServerURI: restund.your.domain:3478?transport=udp
```

Follow the rest of the steps [here](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#deploying)

#### Forwarding traffic

Since HTTP and HTTPS port forwarding has been set up in the previous steps, all we are missing is the UDP.

```
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p udp -m udp --dport 32768:60999 -j DNAT --to-destination $KUBENODEIP
```
