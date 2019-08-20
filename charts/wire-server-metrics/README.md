wire-server-metrics
-------------------

This is mostly a wrapper over https://github.com/helm/charts/tree/master/stable/prometheus-operator
For a full list of overrides, please check the appropriate chart version and its options.

How to use this chart?
----------------------

In its simplest form, install the chart with:
```
helm upgrade --install --namespace <namespace> <name> charts/wire-server-metrics [-f <optional-path-to-overrides>
```

Once the chart is deployed, try to access the grafana dashboard
```
kubectl -n <namespace> port-forward service/<name-of-the-grafana-service> 8080:80
```
