# Monitoring

<!-- vim-markdown-toc GFM -->

* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Adding Dashbaords](#adding-dashbaords)
* [Monitoring in a separate namespace](#monitoring-in-a-separate-namespace)
* [Using Custom Storage Classes](#using-custom-storage-classes)
* [Troubleshooting](#troubleshooting)
* [Monitoring without persistent disk](#monitoring-without-persistent-disk)
* [Using custom storage classes](#using-custom-storage-classes-1)
* [Accessing grafana](#accessing-grafana)
* [Accessing prometheus](#accessing-prometheus)

<!-- vim-markdown-toc -->

## Prerequisites

See the [development setup](https://github.com/wireapp/wire-server-deploy#development-setup)

## Installation

The following instructions detail the installation of a monitoring system consisting
of a Prometheus instance and corresponding Alert Manager in addition to a Grafana
instance for viewing dashboards related to cluster and wire-services health.

If you wish to add custom overrides you can create a values file and pass it alongside
all of the following `helm` commands using `-f values/wire-server-metrics/demo-values.yaml`:

Creating an override file:

```bash
cp values/wire-server-metrics/demo-values.example.yaml values/wire-server-metrics/demo-values.yaml
```

The monitoring system requires disk space if you wish to be resilient to pod
failure. If you are deployed on AWS you may install the `aws-storage` helm
chart which provides configurations of Storage Classes for AWS's elastic block
storage (EBS). If you're not using AWS, instead of using `aws-storage`, you
need to provide your [custom storage class](#using-custom-storage-classes).

First we install the Storage Classes via the `aws-storage` chart:

```
helm upgrade --install demo-aws-storage wire/aws-storage \
    --namespace demo \
    --wait
```

Next we can install the monitoring suite itself

There are a few known issues surrounding the `prometheus-operator` helm chart.

You will likely have to install the Custom Resource Definitions manually before
installing the `wire-server-metrics` chart:

```
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/d34d70de61fe8e23bb21f6948993c510496a0b31/example/prometheus-operator-crd/alertmanager.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/d34d70de61fe8e23bb21f6948993c510496a0b31/example/prometheus-operator-crd/prometheus.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/d34d70de61fe8e23bb21f6948993c510496a0b31/example/prometheus-operator-crd/prometheusrule.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/d34d70de61fe8e23bb21f6948993c510496a0b31/example/prometheus-operator-crd/servicemonitor.crd.yaml
```

Now we can install the metrics chart; from the root of the `wire-server-deploy`
repository run the following:

```
./bin/update.sh charts/wire-server-metrics
helm upgrade --install demo-wire-server-metrics wire/wire-server-metrics \
    --namespace demo \
    --wait
```

See the [Prometheus Operator
README](https://github.com/helm/charts/tree/master/stable/prometheus-operator#work-arounds-for-known-issues)
for more information and troubleshooting help.

## Adding Dashbaords

Grafana dashbaord configurations are included as JSON inside the
`charts/wire-server-metrics/dashboards` directory. You may import these via
Grafana's web UI. See [Accessing grafana](#accessing-grafana).

## Monitoring in a separate namespace

It is advisable to separate your monitoring services from your application services.
To accomplish this you may deploy `wire-server-metrics` into a separate namespace from
`wire-server`. Simply provide a different namespace to the `helm upgrade --install` calls
and adjust the following config option in your `values.yaml`:

```yaml
wire-server-metrics:
  prometheus-operator:
    prometheus:
        rbac:
        # Namespaces which may be monitored by prometheus
        roleNamespaces:
            - kube-system
            - <my-wire-server-namespace>
```

## Using Custom Storage Classes

If you're using a provider other than AWS please reference the [Kubernetes
documentation on storage
classes](https://kubernetes.io/docs/concepts/storage/storage-classes/) for
configuring a storage class for your kubernetes cluster.

## Troubleshooting

If you receive the following error:

```
Error: validation failed: [unable to recognize "": no matches for kind "Alertmanager" in version
"monitoring.coreos.com/v1", unable to recognize "": no matches for kind "Prometheus" in version 
"monitoring.coreos.com/v1", unable to recognize "": no matches for kind "PrometheusRule" in version 
```

Please run the script to install Custom Resource Definitions which is detailed in
the installation instructions above.

---

When upgrading you may see the following error:

```
Error: object is being deleted: customresourcedefinitions.apiextensions.k8s.io "prometheusrules.monitoring.coreos.com" already exists
```

Helm sometimes has trouble cleaning up or defining Custom Resource Definitions.
Try manually deleting the resource definitions and trying your helm install again:

```
kubectl delete customresourcedefinitions \
  alertmanagers.monitoring.coreos.com \
  prometheuses.monitoring.coreos.com \
  servicemonitors.monitoring.coreos.com \
  prometheusrules.monitoring.coreos.com
```

## Monitoring without persistent disk

If you wish to deploy monitoring without any persistent disk (not recommended)
you may add the following overrides to your `values.yaml` file.

```yaml
wire-server-metrics:
  prometheus-operator:
    grafana:
      persistence:
        enabled: false
  prometheusSpec:
    storageSpec: null
  alertmanager:
    alertmanagerSpec:
        storage: null
```

## Using custom storage classes

If you wish to use a different storage class (for instance if you don't run on AWS)
you may add the following overrides to your `values.yaml` file.

```yaml
wire-server-metrics:
  prometheus-operator:
    grafana:
      persistence:
        storageClassName: "<my-storage-class>"
  prometheusSpec:
    storageSpec: 
      volumeClaimTemplate:
        spec:
          storageClassName: "<my-storage-class>"
  alertmanager:
    alertmanagerSpec:
      storage:
        volumeClaimTemplate:
          spec:
            storageClassName: "<my-storage-class>"
```

## Accessing grafana

Forward a port from your localhost to the grafana service running in your cluster:

```
kubectl port-forward service/<release-name>-grafana 3000:80 -n <namespace>
```

Now you can access grafana at `http://localhost:3000`

The username and password are stored in the `grafana` secret of your namespace

By default this is:

- username: `admin`
- password: `admin`

## Accessing prometheus

Forward a port from your localhost to the prometheus service running in your cluster:

```
kubectl port-forward service/<release-name>-prometheus 9090:9090 -n <namespace>
```

Now you can access prometheus at `http://localhost:9090`

