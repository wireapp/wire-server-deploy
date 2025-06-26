# Purpose

This document explains how to instrument the Wire server Kubernetes deployment with Prometheus and Grafana monitoring.

Follow these guidelines to instrument your deployed wire cluster for monitoring. These instructions bring you through  setting up the prometheus operator (with the kube-prometheus-helm stack) to scrape metrics, exposing those metrics as a datasource for Grafana. Additionally, if you are using our wire-in-a-box setup, we setup a grafana VM, with dashboards.

## Instrumentation Overview

- Setup Grafana (optional as the section describes how to setup grafana on a VM for test purpose)
- Configure Prometheus with customized kube-prometheus-stack helm chart
- Configure Prometheus scrape job for wire services
- Importing dashboards into Grafana


## Setup Grafana:
We do not provide grafana instrumentation for the production environment. We expect the customers/clients will bring their own grafana instance and can connect the prometheus datasource which will get shipped to the production environment.

If there is an exiting grafana instance or a new instance needs to be configured for the production environment, we encourage to follow the upstream [grafana installation document](https://grafana.com/docs/grafana/latest/setup-grafana/installation/).

In a test environment if there is no existing grafana then configuring a grafana instance on a VM will be good enough. Here is how to do it by running couple of scripts, in a virsh (wire-in-a-box) environment:

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

Prometheus operator will be configured to scrape metrics from k8s cluster and wire services by installing [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md) helm chart. We have configured this chart with overridden values which will setup the followings:

- An `ingress` to expose the prometheus endpoint if enabled
- Basic authentication to the endpoint
- Automatic certificate creation with cert-manager (Assuming cert-manager is already present in the k8s cluster)
- Setup a local persistent volume to use as prometheus data storage on a certain node
- Disable both Alertmanager and grafana operator which is part of the helm stack.

Before installing the helm chart, there are some works todo. First make sure the `wire-server-deploy` bundle has the `kube-prometheus-stack` chart. If the chart is not there, get it from one of the latest bundle and copy it to the current `charts` directory of the `wire-server-deploy` bundle. In case the `kube-prometheus-stack` chart needs to be copied in the running `wire-server-deploy` bundle there are some extra configurations needs to be made to have a successful deployment. The following sections cover both cases.

### Instrument prometheus to scrape metrics

All the configuration values are defined in the `values.yaml` file in the chart. Before running install/upgrade of the helm chart, please carefully check those values by following the comments in the file.

Get the `kube-prometheus-stack` helm charts in the `/charts` directory, then modify the `kube-prometheus-stack/values.yaml`. Here is the step by step guidelines:

Open the `values.yaml` file and read the configurations.

```bash
cat charts/kube-prometheus-stack/values.yaml
```
There are several configurable parts in values file

- The global part where we define the values to create a local persistent volume in a fixed k8s node.
- Then in the `prometheus:` field we set up the ingress (default value is `false`), certification and basic-auth
- In the `prometheusSpec:` field we first configure the operator to scrape metrics from all the service and pod monitors from any namespace
- In the `prometheusSpec.affinity:` field we configure the prometheus to be pinned on the node where the PV got created.
- In the `storageSpec:` field we configure the storage for prometheus data.

All the sections below described how and what to modify to have a successful prometheus instrumentation.

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

By default the `ingress` is disabled for prometheus, Ingress needs to be enabled for prometheus to use as datasource outside the k8s cluster. To enable the `ingress` update the `kube-prometheus-stack.prometheus.ingress:` field.

Prometheus ingress is configured with `basic-auth` for authetication. Basic auth secrets got created with `offline-secrets.sh` in the `values/kube-prometheus-stack/secrets.yaml` file during the preparation phase of the deployment. Please check the existence of the `values/kube-prometheus-stack/secrets.yaml` file

If there is no `values/kube-prometheus-stack/secrets.yaml` file that means wire-server-deploy bundle does not have the necessary prometheus configuration components in it. To resolve it, either get the `offline-secrets.sh` from the latest bundle and create the secrets or create a `values/kube-prometheus-stack/secrets.yaml` file manually and add the basic auth credentials there as following:

```bash
touch values/kube-prometheus-stack/secrets.yaml
nano values/kube-prometheus-stack/secrets.yaml
```
Add prometheus auth credentials in the secrets.yaml

```yaml
prometheus:
  auth:
    username: <username>
    password: <password>
```

#### Get the domain name and certificate for the prometheus ingress

- hosts: Assuming that the sub domain name for prometheus starts with `prometheus`. So the sub domain would be `prometheus.<domain_name>`. Put the right domain in the `hosts` and `tls.hosts` field.

- secretName: pick a secretName for certificate, for example it could be `prometheus-tls-cert`. After applying this chart cert-manager will create a certificate named `prometheus-tls-cert` and the issuer will be `clusterIssuer`

Cert-manager will facilitate creating managing the TLS signed Certificate resource for the prometheus ingress automatically as we are annotating cert-manager with the ingress-shim for prometheus ingress. It is defined in the `values.yaml` as following:

```yaml
...
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-http01
```
We are using cluster-issuer to acquire the certificate required for this Ingress. It does not matter which namespace your Ingress resides, as ClusterIssuers are non-namespaced resources.

**Get the issuer from k8s env**

```bash
d kubectl get clusterissuer
```
Make sure the `clusterIssuer` present in the k8s environment and if it does not match what we have in the `values.yaml`, replace it with the right one.

If the clusterIssuer does not exist and you only have namespaced scoped `issuer` then convert the `issuer` to `clusterIssuer` by updating the `issuer` `kind` in the `values/nginx-ingress-services/values.yaml`

```yaml
tls:
  enabled: true
  # NOTE: enable to automate certificate issuing with jetstack/cert-manager instead of
  #       providing your own certs in secrets.yaml. Cert-manager is not installed automatically,
  #       it needs to be installed beforehand (see ./../../charts/certificate-manager/README.md)
  useCertManager: false
  issuer:
    kind: ClusterIssuer
```
Save the file and upgrade the nginx-ingress-service helm chart with:

```bash
d helm upgrade --install nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml --values ./values/nginx-ingress-services/secrets.yaml
```

Now the check the issuer again to make sure there is a clusterIssuer in the environment. Also check existing certificates are no have `clusterIssuer` as `issueRef`.

#### Install the helm chart

Before proceeding to this step, make sure the values.yaml file has been updated with the correct values. Now install the kube-prometheus-stack helm.

```bash
d helm upgrade --install prometheus \
  ./charts/kube-prometheus-stack/ \
  -f charts/kube-prometheus-stack/values.yaml \
  -f values/wire-server/secrets.yaml \
  --namespace monitoring \
  --create-namespace
```

- This command installs (or upgrades) the kube-prometheus-stack Helm chart with the release name `prometheus` in the `monitoring` namespace, using custom values.yaml.
- Sets the auth secret for basic auth for prometheus endpoint
- Gets the basic auth secrets from `values/wire-server/secrets.yaml` created with `offline-secrets.sh` script.
- The `--create-namespace` flag will create the namespace if it does not exist.

After successful deployment of the Chart, the output will show all the configured resources including basic auth info.
You should be able to browse the prometheus endpoint with `https://prometheus.<domain>`. Check the targets health once prometheus is ready: `https://prometheus.<domain_name>/targets`.

Check the output with helm status command `$ helm status prometheus -n monitoring`

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
The certificate should also be in the `Ready` state.

#### Scrape the metric from ingress-nginx

To scrape ingress-nginx metrics, `serviceMonitor` needs to be enabled in the `values/ingress-nginx-controller/values.yaml` file. If the `metrics.serviceMonitor` enablement block is not present in the file, it needs to be manually added in the file.

First take a look if the values have the `metrics.serviceMonitor` enablement block. If the block is present then ingress-nginx is ready to get scraped.

```bash
cat values/ingress-nginx-controller/values.yaml
```

If the metrics block is not in the values file then add the following block to the end of the file within `ingress-nginx.controller:` field

```yaml
ingress-nginx:
  controller:
  .....
    # Enable prometheus operator to scrape metrics from the ingress-nginx controller with servicemonitor.
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true
```
Save the file and upgrade the ingress-nginx helm chart.

Before and after running the helm upgrade, find out on which node the ingress-nginx-controller pod is running.

```bash
d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.hostIP
```

```bash
d helm upgrade --install ingress-nginx-controller ./charts/ingress-nginx-controller --values ./values/ingress-nginx-controller/values.yaml
```
Note: After the helm upgrade it might happen that the ingress is scheduled to a different node which may cause the drop of the outbound traffic and you will get a 503 error. To resolve that please follow the [Incoming SSL Traffic section](./docs_ubuntu_22.04.md#incoming-ssl-traffic).

#### Scrape the metrics from the wire services

After the kube-prometheus-stack helm install, the k8s metrics will be scraped by the prometheus operator but not the wire service metrics. To scrape wire service metrics with prometheus, `ServiceMonitor` CRD needs to be enabled for wire services.

If the wire server was configured with the bundle which has kube-prometheus-stack helm chart in the `charts` directory, then enable `ServiceMonitor` for all the wire services in the `values/wire-server/values.yaml` file. 

If the `values/wire-server/values.yaml` contains metrics value like:

```yaml
brig: # as like brig all the services will have the serviceMonitor value in the file.
  ...
  metrics:
    serviceMonitor:
      enabled: false
```

You can run the following command to enable serviceMonitor for all the services

```bash
sed -i '/serviceMonitor:/ {n; s/enabled: .*/enabled: true/;}' values/wire-server/values.yaml
```

Incase the `values/wire-server/values.yaml` file does not contain the  `serviceMonitor` enablement block then it needs to be manually added. As shown above, add the `serviceMonitor` enablement block with `metrics.serviceMonitor.enabled: true` setting for each wire services: `brig, proxy, cannon, cargohold, galley, gundeck, nginz, spar, legalhold, federator, background-worker`. As an example it will look like:

```yaml
background-worker:
  config:
    cassandra:
      host: cassandra-external
    # Enable for federation
    enableFederation: false
  metrics:
    serviceMonitor:
      enabled: true
```
Add the metrics block to all the above-mentioned services.

When `serviceMonitor` enablement block is enabled, please upgrade the wire-server helm chart like:

```bash
d helm upgrade --install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```

After a successful run, it will create `ServiceMonitor` CRD for each wire service which will get scraped by the prometheus operator.
Now the prometheus targets `https://prometheus.<domain_name>/targets` will find the ServiceMonitors of wire services for scraping. Also check any particular metric with labels in the within prometheus query window by providing a metric name, such as: `http_request_duration_seconds_bucket` and run execute.

### Troubleshoot

If the prometheus datasource/query endpoint does not return 200 rather a 503 which means there is something wrong with the configurations. Check the prometheus pod status first.

```bash
d kubectl get pods -n monitoring -owide
```
if the pod `prometheus-prometheus-kube-prometheus-prometheus-*` is not in the `Running` state and still in the initializing phase then take a look at the k8s events

```bash
d kubectl describe pod prometheus-prometheus-kube-prometheus-prometheus-o -n monitoring -oyaml
```

The k8s events will provide enough hints to figure out whats the real issue, if it could not find/attach the storageclass and the volume, just got created via the helm chart. In that case check if the PVC is bound to the right storageclass

```bash
d kubectl get pvc -n monitoring
```
If there is no `bound` then it might require to remove the stale PV and create a new one. And finally check the PV has the `CLAIM` to the prometheus.

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

Test your datasource by clicking the Metrics in the Drilldown section. By choosing the configured datasource you should be able to see the metrics.


### Importing dashboards into Grafana 

In the artifacts dashboards directory, there is a script `dashboards/grafana_sync.sh` which will take care of the uploading all the dashboards from `dashboards/api_upload` directory. Before proceeding to run the script, it requires an API token and Grafana url where the dashboards will be uploaded.

**How to get the API token**

On the left side panel of Grafana, find the `Administration` link, then extend the button or click it.
- Go to `Users and Access` section
- Go to `Service Accounts`
- Add a new service account (provide a display name and Role as either `Editor` or `Admin`)
- Proceed to create the account and then create the token (do not forget to copy the token to a safe place)

Then replace the `<GRAFANA_URL>` and `<API_TOKEN>`  with yours

```bash
cat dashboards/grafana_sync.sh
```
Then run the script

```bash
chmod +x dashboards/grafana_sync.sh
./dashboards/grafana_sync.sh
```

All the dashboards should be uploaded. If the dashboard does not show any graph, refresh the dashboard or open the individual dashboard panel in the `edit` mode and refresh the `Query inspector`.

#### Manual Upload

To upload manually copy the dashboards json from `dashboards/manual_upload` directory and import to your grafana instance one by one.