# Instrument wire application for monitoring

Follow these guidelines to instrument your deployed wire cluster for monitoring. These instructions bring you through  setting up the prometheus operator (with the kube-prometheus-helm stack) to scrape metrics, exposing those metrics as a datasource for Grafana. Additionally, if you are using our wire-in-a-box setup, we setup a grafana VM, with dashboards.

## Setup Grafana:
If there is no existing grafana in your environment then you can setup/install grafana on a VM. Here is how to do it by running couple of scripts, in a virsh (wire-in-a-box) environment:

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

Before installing the helm chart, there are some works todo.

### Update the values.yaml

All the values defined in the values.yaml file are default values and some place holders where the user needs to set the values. Before install/upgrade, please carefully check those values by following the comments in the file.

Get the `kube-prometheus-stack` helm charts in the `/charts` directory, then modify the `kube-prometheus-stack/values.yaml`. Here is the step by step guidelines:

What values need to be modified are documented in the values.yaml file

```bash
cat charts/kube-prometheus-stack/values.yaml
```
And update the values based on your configurations.

#### Define values to create a Local PV

Check the default values to create a persistent volume in the cluster on a certain node (e.g. kubenode3) where the prometheus pod is also pinned.

```yaml
nodeName: kubenode3
storageSize: 50Gi
storageClassName: local-prometheus-storage
volumeMountPath: /mnt/prometheus-data
```
- nodeName: The specific node where the PV will be created, if the nodeName gets changed please update the nodeName in the `nodeAffinity` field too
- storageSize: Give a volume size to the PV
- storageClassName: This class will be used by prometheus to claim the the volume
- volumeMountPath: Node local disk directory where prometheus will store the data

If any of the values get changed, please adjust the corresponding values in the `kube-prometheus-stack.prometheusSpec:` fields and `kube-prometheus-stack.storageSpec:` fields.

**Manually create the mount path directory to configure the PV**

With the default values, the chart will create a persistent volume in the `kubenode3` with the `storageClassName`, `storageSize` and `volumeMountPath` as defined in the `values.yaml`. And the prometheus POD will be pinned to the `kubenode3` with `nodeAffinity` so that the pod can always reschedule on this very node to use the PVC created on this node. The volume mount path needs to be created manually.

Create the volume mount path in the kubenode3 VM and provide necessary permissions for prometheus to access it. Here is how you do it.

```bash
ssh kubenode3
sudo mkdir -p /mnt/prometheus-data
sudo chown -R 65534:65534 /mnt/prometheus-data
sudo chmod 755 /mnt/prometheus-data
```

- ssh to kubenode3
- creates the mount path directory stated in the `charts/kube-prometheus-stack/templates/persistentvolume.yaml`
- sets the Ownership to UID 65534 (nobody). Prometheus runs as a non-root user inside the container for security reasons. In prometheusSpec.securityContext, unless overridden, it runs as 65534
- sets the permissions of the directory so that Prometheus (running as a non-root user) can access and write to it.

#### Ingress and Basic auth credentials
By default the `ingress` is disabled for prometheus, you need to enable it when prometheus will be used as datasource outside the k8s cluster. To enable the `ingress` update the `kube-prometheus-stack.prometheus.ingress:` field . And prometheus ingress uses `basic-auth` for authetication.

#### Get the domain name and certificate

- hosts: Assuming that the sub domain name for prometheus starts with `prometheus`. So the sub domain would be `prometheus.<domain_name>`. Put the right domain in the `hosts` and `tls.hosts` field.

- secretName: pick a secretName for certificate, for example it could be `prometheus-tls-cert`. After applying this chart cert-manager will create a certificate named `prometheus-tls-cert` and the issuer will be `clusterIssuer` with the following spec:

** Get the issuer from k8s env**

```bash
d kubectl get clusterissuer
```
Make sure the `clusterIssuer` present in the k8s environment and if it does not match what we have in the `values.yaml`, replace it with the right one.

**Test the issuer after applying the chart**

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

### Install the helm chart

Before proceeding to this step, make sure the values.yaml file has been updated with the correct values. Now install the kube-prometheus-stack helm.

```bash
d helm upgrade --install prometheus \
  ./charts/kube-prometheus-stack/ \
  -f charts/kube-prometheus-stack/values.yaml \
  -f values/wire-server/secrets.yaml \
  --namespace monitoring \ 
  --create-namespace
```

- This command installs (or upgrades) the kube-prometheus-stack Helm chart with the release name wire-server in the monitoring namespace, using custom values.yaml.
- Sets the auth secret for basic auth for prometheus endpoint
- Gets the basic auth secrets from `values/wire-server/secrets.yaml` created with `offline-secrets.sh` script.
- The `--create-namespace` flag will create the namespace if it does not exist.

After successful deployment of the Chart, the output will show all the configured resources including basic auth info.
we should be able to browse the prometheus with `https://prometheus.<domain>`. Check the targets health once prometheus is ready: `https://prometheus.<domain_name>/targets`.

Check the output with helm status command `$ helm status prometheus -n monitoring`

### Metrics Collection via Prometheus Operator

The **Prometheus Operator** is responsible for scraping metrics from various sources using ServiceMonitors and PodMonitors.

**Metrics Sources:**

- Wire Services: Application-level metrics from all Wire components
- Kube-State Metrics: Resource state information from Kubernetes objects
- Node Metrics: CPU, memory, disk, and other resource usage from all Kubernetes nodes
- API Server Metrics: Performance and request metrics from the Kubernetes API server
- NGINX Ingress Controller Metrics: Request, latency, and error metrics from the Ingress controller

These metrics are discovered and scraped based on label selectors defined in the respective ServiceMonitor and PodMonitor resources.

### Setup prometheus as datasource for grafana

Now open the grafana with the browser and click the Data sources tab. 
- Choose Prometheus as data source and put the prometheus ingress endpoint as connection parameter.
- Select Basic Authentication in the Authentication part and provide the prometheus credentials
- Skip TLS Client Authentication or choose it if you have all the certificate info at hand.

Test you data source by clicking the Metrics in the Drilldown section. Choose you configured datasource and you should be able to see the metrics.

### Dashboards

Import the dashboard JSON's from dashboards directory to get started.
There are two ways dashboards could be uploaded, one is via API and another is manually. Dashboards json has different format for manual and api based upload.

#### Upload via API

In the artifacts dashboards directory, there is a script `dashboards/grafana_sync.sh` which will take care of the uploading all the dashboards from `dashboards/api_upload` directory. Before proceeding to run the script, it requires an API token and Grafana url where the dashboards will be uploaded.

**How to get the API token**

On the left side panel of Grafana, find the `Administration` link, then extend the button or click it.
- Go to `Users and Access` section
- Go to `Service Accounts`
- Add a new service account (provide a display name and Role as either `Editor` or `Admin`)
- Proceed to create the account and then create the token (do not forget to copy the token in safer space)

Then replace the `<GRAFANA_URL>` and `<API_TOKEN>`  with yours

```bash
cat dashboards/grafana_sync.sh
```
Then run the script

```bash
chmod +x dashboards/grafana_sync.sh
./dashboards/grafana_sync.sh
```

All the dashboards should be uploaded.

#### Manual Upload

To upload manually copy the dashboards json from `dashboards/manual_upload` directory and import to your grafana instance one by one.