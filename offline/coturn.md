# Installing Coturn.

Coturn is a free and open-source implementation of TURN and STUN server. 

It is used to relay media between two clients that are unable to establish a direct connection. 

This is useful in cases where the clients are behind a NAT or a firewall.

This document explains how to install Coturn on a newly deployed Wire-Server installation.

This presumes you already have:

* Followed the [single Hetzner machine installation](single_hetzner_machine_installation.md) guide or otherwise have a machine ready to accept a Wire-Server deployment.
* Have followed the [Wire-Server installation](docs_ubuntu_22.04.md) guide and have Wire-Server deployed and working.

## Plan. 

To setup Coturn, we will:

* Create a `values.yaml` file and fill it with configuration.
* Create a `secret.yaml` file for the Coturn secrets.
* Configure the Coturn labels to select on which machine(s) it will run.
* Configure the SFT deployment for node selection and public IP discovery.
* Configure the port redirection in Nftables.
* Change the Wire-Server configuration to use Coturn.
* Install Coturn using Helm.
* Verify that Coturn is working.

This entire document presumes you are working from inside your Wire-Server deployment directory (typically `~/wire-server-deploy/`).

Step by step:

## Create a `values.yaml` file and fill it with configuration.

Create a folder for the Coturn configuration:

```bash

mkdir -p values/coturn

```

Create/edit a `values.yaml` file inside the `values/coturn` folder:

```bash

nano values/coturn/values.yaml

```

Add the following configuration to the `values.yaml` file:

```yaml

# Value file for coturn chart.
#
# See: https://github.com/wireapp/wire-server/blob/develop/charts/coturn/values.yaml
# And: https://github.com/wireapp/wire-server/blob/develop/charts/coturn/README.md

# use nodeSelector only if you are planning on using coturn on fewer than the number of workers in your cluster. This is used to pin coturn to specific nodes.
nodeSelector:
  wire.com/role: coturn

replicaCount: 3
coturnTurnListenIP: "__COTURN_POD_IP__"
coturnTurnExternalIP: "__COTURN_EXT_IP__"
coturnTurnRelayIP: "__COTURN_POD_IP__"
```

Annotate nodes with the wire.com/external-ip annotation if the nodes are behind a 1:1 NAT. This is to make coturn aware of its external IP address.

ie.
```
d kubectl annotate node kubenode1 wire.com/external-ip=IP.ADDRESS
```

## Create a `secret.yaml` file for the Coturn secrets.

For the Coturn secrets, we are going to re-use the wire-server secrets.

First locate your wire-server secrets file:

```bash

cat values/wire-server/secrets.yaml

```

You will see a section like this:

```yaml

brig:
  secrets:
    smtpPassword: dummyPassword
    zAuth:
      publicKeys: "2DaWAtcJ6ZCP[...]0O2Z2_zf-M="
      privateKeys: "t0R49fDju3GVU0LIA[...]KZ99rQ7Znb"
    turn:
      secret: "Ob4C52U8WPwv[...]QUy724p1n"
    awsKeyId: dummykey
    awsSecretKey: dummysecret

``` 

This section, with the secrets, are what we want to copy into our `secret.yaml` file for Coturn.

Create/edit a `secret.yaml` file inside the `values/coturn` folder:

```bash

nano values/coturn/secret.yaml

```

Add the following configuration to the `secret.yaml` file:

```yaml

# Path is .secrets.
secrets:
  zrestSecrets:
    - "Ob4C52U8WPwv[...]QUy724p1n"

``` 

Here, the value for `secrets.zrestSecrets` is the same as `brig.secrets.turn.secret` from the wire-server secrets.

## Configure the Coturn labels to select on which machine(s) it will run.

Next, we must select on which machine Coturn will run.

In this example, we've decided it will run on the third kubernetes node, `kubenode3`, which has an IP address of `192.168.122.23`.

We've set the `nodeSelector` in the `values.yaml` file to select the `coturn` role, this and machine we label with the `wire.com/role: coturn` label will be selected to run Coturn.

So we need to label the `kubenode3` machine with the `wire.com/role: coturn` label.

We do this by running:

```bash

d kubectl label node kubenode3 wire.com/role=coturn

```

By default, only one machine will be selected to run Coturn. 

If you want to run Coturn on multiple machines, you must:

1. Add the `wire.com/role: coturn` label to multiple machines.

2. Change the `replicaCount` in the `charts/coturn/values.yaml` file to the number of machines you want to run Coturn on.

## Configure the SFT deployment for node selection and public IP discovery

First, we must locate what the "external" IP address of the machine is. 

We get it by running the following command:

```bash

sudo ip addr

```

The first interface will be the loopback interface, `lo`, and the second interface will be the "external" interface, `enp41s0` in our example, the output looking something like this:

```bash

demo@install-docs:~/wire-server-deploy$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: enp41s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether a8:a1:59:a2:9b:5b brd ff:ff:ff:ff:ff:ff
    inet 5.9.84.121/32 scope global enp41s0
       valid_lft forever preferred_lft forever
    inet6 2a01:4f8:162:3b6::2/64 scope global 
       valid_lft forever preferred_lft forever
    inet6 fe80::aaa1:59ff:fea2:9b5b/64 scope link 
       valid_lft forever preferred_lft forever
3: etc... 

``` 

In this case, the external IP address is `5.9.84.121`.

Please note: This step is also documented in the [Wire install docs](docs_ubuntu_22.04)

We must make sure that Coturn pods and SFT pods do not run on the same kubernetes nodes.

This means we must label the kubernetes nodes to run on nodes that we did not select to run Coturn in the previous step.

In this example, we've decided to run Coturn on the third kubernetes node, `kubenode3`, which has an IP address of `192.168.122.23`.

First we make sure the SFT chart is configured to only run on kubernetes nodes with the right label (`sftd`).

Edit the `values/sftd/values.yaml` file:

```bash

nodeSelector:
  wire.com/role: sftd

``` 

Then we label the `kubenode1` machine with the `wire.com/role: sftd` label:

```bash

d kubectl label node kubenode1 wire.com/role=sftd

```

We must also annotate the node with the exrenal IP address we will be listening to (which we found with `sudo ip addr` above):

```bash

d kubectl annotate node kubenode3 wire.com/external-ip='your.public.ip.address'

```

If we want to run SFT on multiple nodes, the procedure is the same as the one documented above for running Coturn on multiple nodes.

We now should have Coturn configured to run on one or more kubernetes node(s), and SFT configured to run on one or more kubernetes node(s), and the two should not run on the same node(s)/overlap.

Before moving on, we must also re-deploy SFT's chart to apply the new configuration:

```bash

d helm upgrade --install sftd ./charts/sftd --set 'nodeSelector.wire\.com/role=sftd' --values values/sftd/values.yaml

```

## Configure the port redirection in Nftables.

```{note}

Note: This section is only relevant if you are running Wire-Server/Coturn/SFT behind a `nftables`-managed firewall.

``` 

We must configure the port redirection in Nftables to allow traffic to reach Coturn.

Calling and TURN services (Coturn, SFT) require being reachable on a range of ports used to transmit the calling data. SFT service listens on port 443 which is managed through k8s ingress controller, we must ensure that external traffic for port 443 is able to reach ingress controller.

Here we have decided the following distribution of ports:

* Coturn will operate between ports 32768 and 65535.

We will configure the port redirection in Nftables to allow traffic to reach Coturn.

In the file `/etc/nftables.conf`, which we edit with:

```bash

sudo nano /etc/nftables.conf

```

We will do the following modifications:

First, we create some definitions in the beginning of the file for readability:

```
define COTURNIP   = 192.168.122.23
define KUBENODEIP = 192.168.122.21
define INF_WAN    = enp41s0
``` 

Where:

* `COTURNIP` is the IP address of the machine where Coturn will run (in our example, the third kubernetes node, `kubenode3`).
* `KUBENODEIP` is the IP address of the machine running nginx HTTP / HTTPS ingress.
* `INF_WAN` is the name of the WAN interface exposed to the outside world (the Internet).

Then, we edit the `table ip nat` / `chain PREROUTING` section of the file:

```nft

table ip nat {
  chain PREROUTING {

    type nat hook prerouting priority -100;

    iifname { $INF_WAN, virbr0 } tcp dport 80 fib daddr type local dnat to $KUBENODEIP:31772 comment "HTTP ingress"
    iifname { $INF_WAN, virbr0 } tcp dport 443 fib daddr type local dnat to $KUBENODEIP:31773 comment "HTTPS ingress"

    iifname { $INF_WAN, virbr0 } tcp dport 3478 fib daddr type local dnat to $COTURNIP comment "COTURN control TCP"
    iifname { $INF_WAN, virbr0 } udp dport 3478 fib daddr type local dnat to $COTURNIP comment "COTURN control UDP"

    iifname { $INF_WAN, virbr0 } udp dport 32768-65535 fib daddr type local dnat to $COTURNIP comment "COTURN UDP range"

    fib daddr type local counter jump DOCKER
  }

``` 

Some explanations:

This is used for the HTTP(S) ingress:

```nft 
    iifname { $INF_WAN, virbr0 } tcp dport 80 fib daddr type local dnat to $KUBENODEIP:31772 comment "HTTP ingress"
    iifname { $INF_WAN, virbr0 } tcp dport 443 fib daddr type local dnat to $KUBENODEIP:31773 comment "HTTPS ingress"
``` 

This is the part that routes the UDP packets (media/calling traffic) to the calling services:

```nft
    iifname { $INF_WAN, virbr0 } udp dport 32768-65535 fib daddr type local dnat to $COTURNIP comment "COTURN UDP range"
``` 

This is the part that redirects the control traffic to the Coturn port:

```nft
    iifname { $INF_WAN, virbr0 } tcp dport 3478 fib daddr type local dnat to $COTURNIP comment "COTURN control TCP"
    iifname { $INF_WAN, virbr0 } udp dport 3478 fib daddr type local dnat to $COTURNIP comment "COTURN control UDP"
```


Then we restart Nftables to apply the changes:

```bash

sudo systemctl restart nftables

```

## Change the Wire-Server configuration to use Coturn.

We must change the Wire-Server configuration to use Coturn.

First, we must locate what the "external" IP address of the machine is. 

This is the IP we must provide in our Wire-Server configuration to allow the clients to connect to Coturn. 

We get it by running the following command:

```bash

sudo ip addr

```

For more details on getting the extrenal IP address see the `Configure the SFT deployment for node selection and public IP discovery` section above.

Edit the `values/wire-server/values.yaml` file:

```bash

nano values/wire-server/values.yaml

```

You will find a section that looks like this (default):

```yaml

  turnStatic:
    v1: []
    v2:
      # - "turn:<IP of coturn1>:3478"
      # - "turn:<IP of coturn2>:3478"
      # - "turn:<IP of coturn1>:3478?transport=tcp"
      # - "turn:<IP of coturn2>:3478?transport=tcp"

``` 

Instead, we configure it to use the external IP addres we found above, and the Coturn port, `3478` (as seen above in the `nftables` configuration):

```yaml
  turnStatic:
    v1: []
    v2:
       - "turn:5.9.84.121:3478"
       - "turn:5.9.84.121:3478?transport=tcp"
``` 

As we have changed our Wire-Server configuration, we must re-deploy the Wire-Server chart to apply the new configuration:

```bash

d helm upgrade --install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml

```


## Install Coturn with Helm.

We have now configured our Coturn `value` and `secret` files, configured `wire-server` to use Coturn.

It is time to actually deploy Coturn.

To actually install coturn, you run:

```bash
d helm install coturn ./charts/coturn --timeout=15m0s --values values/coturn/values.yaml --values values/coturn/secret.yaml
```

## Verify that coturn is running.

To verify that coturn is running, you can run:

```bash
d kubectl get pods -l app=coturn
```

Which should give you something like:

```bash
demo@install-docs:~/wire-server-deploy$ d kubectl get pods -l app=coturn
NAME       READY   STATUS    RESTARTS   AGE
coturn-0   1/1     Running   0          1d
```

## Appendix: Debugging procedure.

If coturn has already been installed once (for example if something went wrong and you are re-trying), before running a new deploy of Coturn first do:

```bash
d helm uninstall coturn
```

Also make sure you stop any running coturn service:

```bash
d kubectl delete pod -l app=coturn
```

And then re-run the `helm install` command.

```bash
d helm install coturn ./charts/coturn --timeout=15m0s --values values/coturn/values.yaml --values values/coturn/secret.yaml
```

For further debugging, enable `verboseLogging` in `charts/coturn/values.yaml` and redeploy coturn:

```yaml
config:
  verboseLogging: true
```

```bash
d helm uninstall coturn
d helm install coturn ./charts/coturn --timeout=15m0s --values values/coturn/values.yaml --values values/coturn/secret.yaml
```

Debug log should now be visible in the coturn pod stdout:

```bash
d kubectl logs coturn-0
```

Check if the pod has the correct IP configuration in place.

```bash
d kubectl exec -it coturn-0 -- bash
grep ip= coturn-config/turnserver.conf

# output will look something like this

listening-ip=xxx.xxx.xxx.xxx
relay-ip=xxx.xxx.xxx.xxx.xxx
external-ip=xxx.xxx.xxx.xxx
```


## Appendix: Note on migration.

The current guide is written with the assumption that you are setting up Coturn for the first time, on a fresh Wire-Server installation.

If you are migrating from Restund to Coturn to an existing/running/in-use installation, as clients are currently using Restund, you can not disable Restund before all clients have migrated to Coturn, which they do by retrieving a freshly updated calling configuration from Wire-Server that instructs them to use the Coturn IPs instead of the Restund IPs.

This configuration update occurs every 24 hours, so you will have to wait at least 24 hours before you can disable Restund.

These are the additional steps to ensure a smooth transition:

1. Deploy Coturn as described in this guide, without disabling Restund yet.
2. Change the `turnStatic` call configuration in the `values/wire-server/values.yaml` file to use the Coturn IPs instead of the Restund IPs.
3. Re-deploy the Wire-Server chart to apply the new configuration.
4. Wait at least 24 hours for all clients to retrieve the new configuration.
5. Once you are sure all clients have migrated to Coturn, you can disable Restund as described in this guide below.

## Disable Restund.

As we are no longer using Restund, we should now disable it entirely.

We do this by editing the `hosts.ini` file:

Edit `ansible/inventory/offline/hosts.ini`, and comment out the restund section by adding `#` at the beginning of each line :

```
[restund]
# ansnode1
# ansnode2
```

Then connect to each ansnode and do:

```bash
sudo service restund stop
```

And check it is stopped with: 

```bash
sudo service restund status
```