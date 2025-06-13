# Instrument wire application for monitoring

Follow the guidelines on how to instrument the wire app for monitoring by setting the prometheus operator with kube-prometheus-helm stack to scrape metrics and use the prometheus as datasource for Grafana instance.

## Setup Grafana:
If there is no existing grafana in your environment then setup/install grafana on a VM. Here is how to do it by running couple of scripts.

### Configure a VM for grafana

Make sure the `/bin` directory contains both `grafana-vm.sh` and `install-grafana.sh` scripts.

Run `grafana-vm.sh`

```bash
$ chmod +x  .bin/grafana-vm.sh
$ .bin/grafana-vm.sh
```

This script will setup a VM with ip address `192.168.122.100` and name `grafananode`. This may take up to 30 minutes depending on your hardware. When it's done the VM state will be `Shut Off` and then it's need to started manually.

#### Check VM state and restart

```bash
sudo virsh list --all
sudo virsh start grafananode
```
When the VM is ready, you will be able to `ssh` to the VM. Now we can start installing Grafana.

#### Install Grafana on the grafananode VM

Run `install-grafana.sh` on grafananode VM. You can copy the file from `/bin` directory to the grafananode and can run from the host machine as following:

```ssh
scp -i ~/.ssh/id_ed25519 ./bin/install-grafana.sh demo@192.168.122.100:/tmp/
ssh demo@192.168.122.100 'bash /tmp/install-grafana.sh'
```
This script will install grafana on the VM which is not accessible outside of the host machine. To make it accessible, we need to update the `iptables` rule of the host machine:

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 3000 -j DNAT --to-destination 192.168.122.100:3000
sudo iptables -A FORWARD -p tcp -d 192.168.122.100 --dport 3000 -j ACCEPT
```

Now the grafana can be accessed via a Web browser with the address: `http://<host-machine-ip>:3000`.
Note: exposing Grafana to the network may have security implications and users should secure their instance (change default password, use firewalls, etc.)


## Configure Prometheus

Prometheus operator will be configured to scrape metrics from k8s cluster and wire services by installing (kube-prometheus-stack)[https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md] helm chart. We have configured this chart with overridden values which will setup the followings:

- An `ingress` to expose the prometheus endpoint
- Basic authentication to the endpoint
- Automatic certificate creation with cert-manager (Assuming cert-manager is already present in the k8s cluster)
- Disable both Alertmanager and grafana operator which is part of the helm stack.

Before installing the helm chart, there are some work todo.

### Update the values.yaml

Get the `kube-prometheus-stack` helm charts in the `/charts` directory then modify the `kube-prometheus-stack/values.yaml`. Here is the step by step guidelines:

What values need to be modified are documented in the values.yaml file

```bash
cat charts/kube-prometheus-stack/values.yaml
```
And update the values based on your configurations.

#### Get the domain name and certificate

- hosts: Assuming that the sub domain name for prometheus starts with `prometheus`. So the sub domain would be `prometheus.<domain_name>`. Put the right domain in the `hosts` and `tls.hosts` field.

- secretName: pick a secretName for certificate, for example it could be `prometheus-tls-cert`. After applying this chart cert-manager will create a certificate named `prometheus-tls-cert` and the issuer will be `clusterIssuer` with the following spec:

```bash
d kubectl get certificate prometheus-tls-cert -n <namespace> -o yaml
```

The spec of the certificate will look like the following:

```yaml
...
spec:
  dnsNames:
  - prometheus.<domain_name>
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: letsencrypt-http01
  secretName: prometheus-tls-cert
  ....
```

**But to make it working there is a tiny manual task to do:**

Create the volume mount path in the kubenode3 VM and provide necessary permissions for prometheus to access it. Here is how you do it.

```ssh
ssh kubenode3
sudo mkdir -p /mnt/prometheus-data
sudo chown -R 65534:65534 /mnt/prometheus-data
sudo chmod 755 /mnt/prometheus-data
```

- ssh to kubenode3
- creates the mount path directory stated in the `charts/kube-prometheus-stack/templates/persistentvolume.yaml`
- sets the Ownership to UID 65534 (nobody). Prometheus runs as a non-root user inside the container for security reasons. In prometheusSpec.securityContext, unless overridden, it runs as 65534
- sets the permissions of the directory so that Prometheus (running as a non-root user) can access and write to it.

### Install the helm chart

Before proceeding to this step, make sure the values.yaml file has been updated with the correct values. Now install the kube-prometheus-stack helm.

```bash
d helm upgrade --install wire-server \
  ./charts/kube-prometheus-stack/ \
  -f charts/kube-prometheus-stack/values.yaml \
  -f values/kube-prometheus-stack/authsecret.yaml \
  --namespace monitoring \ 
  --create-namespace
```

- This command installs (or upgrades) the kube-prometheus-stack Helm chart with the release name wire-server in the monitoring namespace, using custom values.yaml.
- Sets the auth secret for basic auth for prometheus endpoint
- The `--create-namespace` flag will create the namespace if it does not exist.
- Prometheus instances created by the operator are configured to *only discover ServiceMonitors and PodMonitors that have the same release label and are in the same namespace* (unless you explicitly change the selectors). So, having a consistent release name is very import for prometheus to scrape metrics correctly.

After successful deployment of the Chart, we should be able to browse the prometheus with https://prometheus.<domain>. Check the targets health once prometheus is ready: https://prometheus.<domain_name>/targets. 

### How to get the secret to login to prometheus query endpoint and configure as datasource

The auth secret is auto generated user and password through wire deployment process. Look into the `plainTextAuth` value which is formatted as
`user:password`

```ssh
cat values/kube-prometheus-stack/authsecret.yaml`
```

### Setup prometheus as datasource for grafana

Now open the grafana with the browser and click the Data sources tab. 
- Choose Prometheus as data source and put the prometheus ingress endpoint as connection parameter.
- Select Basic Authentication in the Authentication part and provide the prometheus credentials
- Choose TLS Client Authentication (optional) or you can also skip it.

Test you data source by clicking the Metrics in the Drilldown section. Choose you configured datasource and you should be able to see the metrics.

### Dashboards

Import the dashboard JSON's from dashboards directory to get started.