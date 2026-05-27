# Purpose

This document explains how to instrument the Wire server Kubernetes deployment with Prometheus and Grafana monitoring.

Follow these guidelines to instrument your deployed Wire cluster for monitoring. These instructions walk you through setting up the Prometheus Operator with the kube-prometheus-stack Helm chart to scrape metrics and exposing those metrics as a data source for Grafana. The steps below assume that the user has already deployed the Wire Backend using our instructions at [Wire in a Box (WIAB) Staging](./wiab-staging.md) or [How to install wire (offline cluster)](./docs_ubuntu_22.04.md).

## Instrumentation Overview

- Verify prerequisites on the adminhost and cluster nodes
- Set up Grafana (optional for test environments)
- Configure Prometheus with the customized kube-prometheus-stack Helm chart
- Enable ServiceMonitors for ingress-nginx, wire services, and SFTD
- Verify that Prometheus is scraping targets and Grafana can query them
- Import dashboards into Grafana

## Prerequisites

Run the commands in this document from the root of the extracted `wire-server-deploy` bundle on the adminhost unless the section explicitly says to run a command on another machine.

Before you start, make sure the following are available:

- A deployed offline Wire cluster as described in [Wire in a Box (WIAB) Staging](./wiab-staging.md) or [How to install wire (offline cluster)](./docs_ubuntu_22.04.md)
- Access to the adminhost with the `d` helper loaded, so `d helm ...`, `d kubectl ...`, `d yq ...`, and `d bash` work
- A reachable Kubernetes node that will host the Prometheus local PV, for example `kubenode3`
- A Grafana instance, or a dedicated VM if you want to install Grafana for test purposes
- The values files that will be updated in this guide:
  - `charts/kube-prometheus-stack/values.yaml`
  - `values/ingress-nginx-controller/values.yaml`
  - `values/wire-server/values.yaml`
  - `charts/sftd/values.yaml` if SFTD monitoring is required

If the bundle does not already contain the required Prometheus chart or container images, prepare them before continuing:

- If `charts/kube-prometheus-stack` is missing, follow [Getting the helm chart](#getting-the-helm-chart).
- If the Prometheus-related container images are not already present on the target node, follow [Download and load the dependent images](#download-and-load-the-dependent-images).

### Back up the values files before editing

Take a backup of each values file that you will modify so you can revert individual changes if needed.

```bash
timestamp="$(date +%F-%H%M%S)"

[ -f charts/kube-prometheus-stack/values.yaml ] && cp charts/kube-prometheus-stack/values.yaml "charts/kube-prometheus-stack/values.yaml.bak.${timestamp}"
[ -f values/ingress-nginx-controller/values.yaml ] && cp values/ingress-nginx-controller/values.yaml "values/ingress-nginx-controller/values.yaml.bak.${timestamp}"
[ -f values/wire-server/values.yaml ] && cp values/wire-server/values.yaml "values/wire-server/values.yaml.bak.${timestamp}"

# Only if you enable SFTD metrics later in this guide.
[ -f charts/sftd/values.yaml ] && cp charts/sftd/values.yaml "charts/sftd/values.yaml.bak.${timestamp}"
```


## Set Up Grafana
We do not provide Grafana instrumentation for the production environment. We expect customers to bring their own Grafana instance and connect it to the Prometheus data source that will be shipped to the production environment.

If there is an existing Grafana instance, or if a new instance needs to be configured for the production environment, follow the upstream [Grafana installation document](https://grafana.com/docs/grafana/latest/setup-grafana/installation/). If you already have Grafana set up, continue with the [Prometheus instructions](#configure-prometheus).

In a test environment, if there is no existing Grafana instance, configuring Grafana on a VM is sufficient.

### Configure a VM for Grafana

Note: Skip this section if you have your own hypervisor to set up VMs and continue with [installing Grafana](#install-grafana-on-the-grafananode-vm).

Make sure the `wire-server-deploy/bin` directory on your adminhost contains the `grafana-vm.sh` script, if not copy/download it at [grafana-vm.sh](../bin/grafana-vm.sh). It would require `sudo` privileges inside the script, so make sure the user running it has `sudo` access.

Run `grafana-vm.sh`

```bash
$ chmod +x bin/grafana-vm.sh
$ bin/grafana-vm.sh
```

This script will set up a VM with a dynamic IP from `192.168.122.0/24`, user `demo`, and hostname `grafananode`. Expect the IP address to be displayed in the output and the SSH key to be present at `wire-server-deploy/ssh`.

### Install Grafana on the grafananode VM

Make sure the `wire-server-deploy/bin` directory on your adminhost contains the `install-grafana.sh` script, if not copy/download it at [install-grafana.sh](../bin/install-grafana.sh). Run `install-grafana.sh` on the `grafananode` VM. The script needs internet access to download the Grafana packages.

You can copy the file from the `bin/` directory to `grafananode` and run it from the adminhost as follows:

```bash
scp -i ssh/id_ed25519 bin/install-grafana.sh demo@grafananode:install-grafana.sh
ssh -i ssh/id_ed25519 demo@grafananode 'bash install-grafana.sh'
```

This script installs Grafana on the VM and starts the service. However, Grafana is only accessible on the VM network. To make it accessible on the adminhost network, add `nft` rules on the `adminhost` machine as follows:

```bash
# Host WAN interface name
INF_WAN=enp9s0
sudo nft insert rule ip nat PREROUTING position 0 iifname $INF_WAN  tcp dport 3000 dnat to grafananode:3000
```

Grafana can now be accessed from a web browser at `http://<adminhost>:3000`.
Note: exposing Grafana to the network may have security implications and users should secure their instance (change default password, use firewalls, etc.)

To log in to Grafana for the first time, use the default credentials provided by Grafana. After logging in, immediately change the credentials as recommended in [the grafana document](https://grafana.com/docs/grafana/latest/setup-grafana/sign-in-to-grafana/).

## Configure Prometheus

The Prometheus Operator will be configured to scrape metrics from the Kubernetes cluster and Wire services by installing the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md) Helm chart. We have configured this chart with overridden values that set up the following:

- Setup a local persistent volume to use as prometheus data storage on a certain node
- Disable both Alertmanager and the Grafana component that is part of the Helm stack

Before we proceed with installation, make sure the `wire-server-deploy` bundle has the `kube-prometheus-stack` chart and helm chart values are configured.

### Getting the helm chart
If the chart is not present, then download it in this step. If the directory `charts/kube-prometheus-stack` already exists then please continue with [Instrument prometheus to scrape metrics](#instrument-prometheus-to-scrape-metrics).

```bash
mkdir -p charts
curl -O https://s3-eu-west-1.amazonaws.com/public.wire.com/charts/kube-prometheus-stack-0.1.5.tgz
tar -xf kube-prometheus-stack-0.1.5.tgz -C charts
```

If the chart was missing from the `charts/` directory, also download all dependent images for the Helm chart as follows.

### Download and load the dependent images

```bash
mkdir -p prometheus-images-tars

images=(
  "quay.io/prometheus/node-exporter:v1.9.1"
  "quay.io/prometheus-operator/prometheus-operator:v0.83.0"
  "quay.io/prometheus/prometheus:v3.4.2"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.4"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.16.0"
)

# logic to find the above images
# d helm template test charts/kube-prometheus-stack | yq eval '.. | select(has("image")) | .image' | grep -i "/" | sort | uniq

for image in "${images[@]}"; do
  docker pull "$image"

  tar_name="$(echo "$image" | sed 's#[/:]#_#g').tar"
  docker save -o "prometheus-images-tars/$tar_name" "$image"
done
```

Copy all the images to kubenode3:
```bash
scp -i ssh/id_ed25519 -r prometheus-images-tars demo@kubenode3:/home/demo/prometheus-images-tars
```

Load all images to ctr:
```bash
ssh -i ssh/id_ed25519 demo@kubenode3 '
  for tar_file in /home/demo/prometheus-images-tars/*.tar; do
    sudo ctr -n k8s.io images import "$tar_file"
  done

  sudo ctr -n k8s.io images list | grep -E "node-exporter|prometheus-operator|prometheus|kube-webhook-certgen|kube-state-metrics"
'
```

### Instrument prometheus to scrape metrics

All the configuration values are defined in the `charts/kube-prometheus-stack/values.yaml` file in the chart. Before running install or upgrade of the Helm chart, carefully review those values by following the comments in the file.

```yaml
# Variables to set locaL PVC Oon kubenode for Prometheus storage
# If this values get modified, please adjust the `nodeName` storageSize and `storageClassName` in the prometheusSpec:
nodeName: kubenode3
storageSize: 50Gi
storageClassName: local-prometheus-storage
volumeMountPath: /mnt/prometheus-data

# This is the custom values.yaml file for the Prometheus stack Helm chart.
kube-prometheus-stack:
  prometheus:
    ingress:
      enabled: false
    service:
      type: NodePort
      nodePort: 30090
    
    prometheusSpec:
      serviceMonitorSelector: {}
      serviceMonitorNamespaceSelector: {}
      serviceMonitorSelectorNilUsesHelmValues: false
      podMonitorSelector: {}
      podMonitorNamespaceSelector: {}
      podMonitorSelectorNilUsesHelmValues: false

      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - kubenode3 
      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: local-prometheus-storage
            accessModes: ["ReadWriteOnce"]
            resources:
              requests:
                storage: 50Gi

      retention: 15d
      retentionSize: 45GiB
      # Enable the Prometheus Operator to use the fallback scrape protocol only for the coturn service.
      # This is useful for services that do not expose Prometheus metrics in the standard format.
      additionalScrapeConfigs:
      - job_name: 'coturn-with-fallback'
        fallback_scrape_protocol: "PrometheusText0.0.4"
        scrape_interval: 30s
        scrape_timeout: 10s
        metrics_path: /metrics
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
            - default
        relabel_configs:
        # Keep only coturn service endpoints
        - source_labels: [__meta_kubernetes_service_name]
          action: keep
          regex: coturn
        # Keep only the status-http port
        - source_labels: [__meta_kubernetes_endpoint_port_name]
          action: keep
          regex: status-http
        # Set the target address
        - source_labels: [__address__]
          target_label: __address__
        # Add service name as a label
        - source_labels: [__meta_kubernetes_service_name]
          target_label: service
        # Add namespace as a label
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        # Add pod name as instance
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
  # Both Grafana and Alertmanager is disabled in this configuration.
  grafana:
    enabled: false
  alertmanager:
    enabled: false
```

There are several configurable parts in the values file:

- The global part where we define the values to create a local persistent volume on a fixed k8s node i.e. `kubenode3`. If you have your own storage class then skip configuring the `storageClassName`, `.storageSize`, `.volumeMountPath` and `.nodeName`.
- Then in the `prometheus:` field we keep ingress disabled and configure the service as a `NodePort`
- In the `prometheusSpec:` field we first configure the operator to scrape metrics from all the service and pod monitors from any namespace
- In the `prometheusSpec.affinity:` field we configure the prometheus to be pinned on the node where the PV got created and where we have loaded our docker images.
- In the `storageSpec:` field we configure the storage for prometheus data.

The sections below describe what to modify to complete the Prometheus instrumentation successfully.

#### Define values to create a Local PV

A local Persistent Volume (local PV) is used in this setup to provide reliable, high-performance, and persistent storage for Prometheus data within an air-gapped or on-premises Kubernetes environment.

In air-gapped environments without access to cloud storage or external networked storage, a local PV is a practical way to provide persistent storage using the node’s own disks.

Check the default values to create a persistent volume in the cluster on a certain node (e.g. kubenode3) where the prometheus pod is also pinned.

```yaml
nodeName: kubenode3
storageSize: 50Gi
storageClassName: local-prometheus-storage
volumeMountPath: /mnt/prometheus-data
```
- nodeName: The specific node where the PV will be created, if the nodeName gets changed please update the nodeName in the `nodeAffinity` field too
- storageSize: Give a volume size to the PV
- storageClassName: This class will be used by Prometheus to claim the volume
- volumeMountPath: Node local disk directory where prometheus will store the data

If any of the values get changed, please adjust the corresponding values in the `kube-prometheus-stack.prometheusSpec:` fields and `kube-prometheus-stack.storageSpec:` fields.

**Manually create the mount path directory to configure the PV**

With the default values, the chart will create a persistent volume in the `kubenode3` with the `storageClassName`, `storageSize` and `volumeMountPath` as defined in the `values.yaml`. And the prometheus POD will be pinned to the `kubenode3` with `nodeAffinity` so that the pod can always reschedule on this very node to use the PVC created on this node. The volume mount path needs to be created manually.

Create the volume mount path in the kubenode3 VM and provide necessary permissions for prometheus to access it. Here is how you do it.

```bash
ssh -i ssh/id_ed25519 demo@kubenode3 "sudo mkdir -p /mnt/prometheus-data && sudo chown -R 65534:65534 /mnt/prometheus-data && sudo chmod 755 /mnt/prometheus-data"
```

- ssh to kubenode3
- creates the mount path directory stated in the `charts/kube-prometheus-stack/templates/persistentvolume.yaml`
- sets the Ownership to UID 65534 (nobody). Prometheus runs as a non-root user inside the container for security reasons. In prometheusSpec.securityContext, unless overridden, it runs as 65534
- sets the permissions of the directory so that Prometheus (running as a non-root user) can access and write to it.

#### Install the helm chart

Before proceeding to this step, make sure the values.yaml file has been updated with the correct values. Now install the kube-prometheus-stack helm.

```bash
d helm upgrade --install prometheus \
  ./charts/kube-prometheus-stack/ \
  -f charts/kube-prometheus-stack/values.yaml \
  --namespace monitoring \
  --create-namespace
```

- This command installs (or upgrades) the kube-prometheus-stack Helm chart with the release name `prometheus` in the `monitoring` namespace, using custom values.yaml.
- Overrides the values of the upstream chart `kube-prometheus-stack` with custom values defined in the `charts/kube-prometheus-stack/values.yaml`
- The `--create-namespace` flag will create the namespace if it does not exist.

After a successful deployment of the chart, the output will show all configured resources and some useful commands that can be issued inside `d`.
You should be able to reach the Prometheus endpoint locally at `http://<kubenode3-ip>:30090`.

## Configure Wire services Helm charts to enable metrics

### Scrape Metrics from ingress-nginx-controller

To scrape ingress-nginx-controller metrics, `metrics.enabled` and `metrics.serviceMonitor.enabled` must be enabled in `values/ingress-nginx-controller/values.yaml`.

Run the following command to configure ingress-nginx metrics scraping. It works both when the block already exists and when it is missing.

```bash
d yq eval -i '."ingress-nginx".controller.metrics.enabled = true | ."ingress-nginx".controller.metrics.serviceMonitor.enabled = true' values/ingress-nginx-controller/values.yaml
```

Verify that the values were set:

```bash
d yq eval '{"metricsEnabled": ."ingress-nginx".controller.metrics.enabled, "serviceMonitorEnabled": ."ingress-nginx".controller.metrics.serviceMonitor.enabled}' values/ingress-nginx-controller/values.yaml
```

The output should look like this:

```yaml
metricsEnabled: true
serviceMonitorEnabled: true
```

Then upgrade the ingress-nginx helm chart.

```bash
d helm upgrade --install ingress-nginx-controller ./charts/ingress-nginx-controller --values ./values/ingress-nginx-controller/values.yaml
```

### Scrape the metrics from the wire services

After the kube-prometheus-stack Helm installation, Kubernetes metrics will be scraped by the Prometheus Operator, but Wire service metrics will not. To scrape Wire service metrics with Prometheus, `ServiceMonitor` resources must be enabled for the Wire services.

If the Wire server was configured with a bundle that contains the kube-prometheus-stack Helm chart in the `charts` directory, enable `ServiceMonitor` for the Wire services in `values/wire-server/values.yaml`.

Run the following command to configure `metrics.serviceMonitor.enabled: true` for all required services. It works both when the `serviceMonitor` block already exists and when it is missing.

A service entry in `values/wire-server/values.yaml` may already contain values like:

```yaml
brig: # as like brig all the services will have the serviceMonitor value in the file.
  ...
  metrics:
    serviceMonitor:
      enabled: false
```

```bash
d yq eval -i '
  .brig.metrics.serviceMonitor.enabled = true |
  .proxy.metrics.serviceMonitor.enabled = true |
  .cannon.metrics.serviceMonitor.enabled = true |
  .cargohold.metrics.serviceMonitor.enabled = true |
  .galley.metrics.serviceMonitor.enabled = true |
  .gundeck.metrics.serviceMonitor.enabled = true |
  .nginz.metrics.serviceMonitor.enabled = true |
  .spar.metrics.serviceMonitor.enabled = true 
' values/wire-server/values.yaml
```

Verify that the values were set:

```bash
d yq eval '{"brig": .brig.metrics.serviceMonitor.enabled, "proxy": .proxy.metrics.serviceMonitor.enabled, "cannon": .cannon.metrics.serviceMonitor.enabled, "cargohold": .cargohold.metrics.serviceMonitor.enabled, "galley": .galley.metrics.serviceMonitor.enabled, "gundeck": .gundeck.metrics.serviceMonitor.enabled, "nginz": .nginz.metrics.serviceMonitor.enabled, "spar": .spar.metrics.serviceMonitor.enabled}' values/wire-server/values.yaml
```

The output should look like this:

```yaml
brig: true
proxy: true
cannon: true
cargohold: true
galley: true
gundeck: true
nginz: true
spar: true
```

If your deployment requirements also include `federator` or `background-worker`, enable their `metrics.serviceMonitor.enabled` values separately and include them in your verification output only when those components are part of the deployment.

When `serviceMonitor` enablement block is enabled, please upgrade the wire-server helm chart like:

```bash
d helm upgrade --install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml
```

After a successful run, it will create `ServiceMonitor` CRD for each wire service which will get scraped by the prometheus operator.

Verify that the ServiceMonitors were created in the `default` namespace:

```bash
d kubectl get servicemonitors -n default
```

If you want to verify only the core Wire service monitors, you can filter them:

```bash
d kubectl get servicemonitors -n default | grep -E "brig|proxy|cannon|cargohold|galley|gundeck|nginz|spar"
```

If you also enabled optional services such as `background-worker` or `federator`, extend the filter accordingly.

Query the Prometheus HTTP API from a machine that can reach `http://<kubenode3-ip>:30090`:

```bash
curl -s "http://<kubenode3-ip>:30090/api/v1/targets?state=active" | jq '.data.activeTargets[] | select(.labels.namespace == "default") | {job: .labels.job, service: .labels.service, pod: .labels.pod, health: .health}'
```

This returns the active targets being scraped from the `default` namespace, including the targets discovered through ServiceMonitors. If the Wire service targets appear here with `health` set to `up`, Prometheus is scraping them.

### Metrics Collection via Prometheus Operator

The **Prometheus Operator** is responsible for scraping metrics from various sources using ServiceMonitors and PodMonitors.

**Metrics Sources:**

- Wire Services: Application-level metrics from all Wire components
- Kube-State Metrics: Resource state information from Kubernetes objects
- Node Metrics: CPU, memory, disk, and other resource usage from all Kubernetes nodes
- API Server Metrics: Performance and request metrics from the Kubernetes API server
- NGINX Ingress Controller Metrics: Request, latency, and error metrics from the Ingress controller

These metrics are discovered and scraped based on label selectors defined in the respective ServiceMonitor and PodMonitor resources.

#### Metrics for calling services

**COTURN Metrics**

Coturn metrics are scraped by the Prometheus Operator with a `scrapeConfig` job defined in the chart values file. When the chart is installed, it automatically configures the `coturn-with-fallback` job. It is defined this way to add `fallback_scrape_protocol: "PrometheusText0.0.4"` so the Prometheus Operator can scrape the metrics. By default, the content type is blank and Prometheus rejects the scrape.

**SFTD metrics**

To enable SFTD metrics, you need to enable the SFTD `serviceMonitor` in the `charts/sftd/values.yaml` file.

Open `values.yaml` and update `metrics.serviceMonitor.enabled` to `true`.

```bash
nano charts/sftd/values.yaml
```
```yaml
metrics:
  serviceMonitor:
    enabled: true
```
Then run the `sftd` helm upgrade command

```bash
d helm upgrade --install sftd ./charts/sftd --set 'nodeSelector.wire\.com/role=sftd' --values values/sftd/values.yaml
```

### Set Up Prometheus as a Datasource for Grafana

Open Grafana in a browser and click the Data sources tab.
- Choose Prometheus as the data source and use the Prometheus endpoint as the connection parameter.

Test the data source by clicking Metrics in the Drilldown section. After choosing the configured data source, you should be able to see metrics.

### Verify Metrics in Grafana Explore

After the Prometheus data source is configured, verify the scrape status in Grafana:

1. Open Grafana and go to **Explore**.
2. Select the Prometheus datasource.
3. Run a simple query such as `up` to confirm that Prometheus is returning time series.
4. Run `prometheus_target_scrape_pool_targets` to see the number of targets in each scrape pool.
5. Run `sum(prometheus_target_scrape_pool_targets)` to plot the total number of endpoints currently configured for scraping.

If `prometheus_target_scrape_pool_targets` does not return data, check Prometheus itself in `http://<kubenode3-ip>:30090/targets` and confirm the Prometheus server is healthy and scraping its own internal metrics.

### Troubleshoot

If the Prometheus data source or query endpoint returns `503` instead of `200`, there is likely a configuration issue. Check the Prometheus pod status first.

```bash
d kubectl get pods -n monitoring -owide
```

If the pod `prometheus-prometheus-kube-prometheus-prometheus-*` is not in the `Running` state and is still initializing, inspect the Kubernetes events.

```bash
d kubectl describe pod prometheus-prometheus-kube-prometheus-prometheus-o -n monitoring -oyaml
```

The Kubernetes events usually provide enough detail to identify the issue. If Prometheus cannot find or attach the storage class or volume that was created by the Helm chart, check whether the PVC is bound to the correct storage class.

```bash
d kubectl get pvc -n monitoring
```

If the status is not `Bound`, you may need to remove the stale PV and create a new one by rerunning the Helm chart.

### Import Dashboards into Grafana

In the artifacts dashboards directory, there is a script `dashboards/grafana_sync.sh` that uploads all dashboards from the `dashboards/api_upload` directory. This directory contains JSON dashboards tailored for API upload. The dashboards come in two variants, one for manual upload and one for API upload. The following sections describe both options.


#### Upload via API

Before running the script, make sure you have an API token and the Grafana URL where the dashboards will be uploaded.

**How to get the API token**

On the left side panel of Grafana, find the `Administration` link, then extend the button or click it.
- Go to `Users and Access` section
- Go to `Service Accounts`
- Add a new service account (provide a display name and Role as either `Editor` or `Admin`)
- Proceed to create the account and then create the token (do not forget to copy the token to a safe place)

Replace `<GRAFANA_URL>` and `<API_TOKEN>` with the Grafana instance URL and the token you just created. Make sure you can reach the Grafana URL from the machine where the script will run.

```bash
cat dashboards/grafana_sync.sh
```
Then run the script

```bash
chmod +x dashboards/grafana_sync.sh
./dashboards/grafana_sync.sh
```

#### Manual Upload

`dashboards/manual_upload` directory consists the dashboard JSON's which can be uploaded manually. To upload manually,

- Go to the left menu → **Dashboards → Import**
- Click **Upload JSON file** and select your file from `dashboards/manual_upload` directory
- Set the Prometheus datasource (usually detected automatically)
- Click "Import"


All the dashboards should be uploaded. If the dashboard does not show any graph, refresh the dashboard or open the individual dashboard panel in the `edit` mode and refresh the `Query inspector`.
