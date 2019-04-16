# Deploying logging for the staging cluster:

## Deploying ElasticSearch
```
helm dep update charts/elasticsearch-6-ephemeral/
helm install --namespace <namespace> charts/elasticsearch-6-ephemeral/
```

note that since we are not specifying a release name during helm install, it generates a 'verb-noun' pair, and uses it.
Elasticsearch's chart does not use the release name of the helm chart in the pod name, sadly.


## Deploying Kibana
```
helm dep update charts/kibana/
helm install --namespace <namespace> charts/kibana/
```

note that since we are not specifying a release name during helm install, it generates a 'verb-noun' pair, and uses it. if you look at your pod names, you can see this name prepended to your pods in 'kubectl -n <namespace> get pods'.

## Deploying fluent-bit
```
helm dep update charts/fluent-bit/
helm install --namespace <namespace> charts/fluent-bit/
```

alternately, if there is already fluent-bit deployed in your environment, get the helm name for the deployment (verb-noun prepended to the pod name), and
helm upgrade <helm-name> --namespace <namespace> charts/fluent-bit/

note that since we are not specifying a release name during helm install, it generates a 'verb-noun' pair, and uses it. if you look at your pod names, you can see this name prepended to your pods in 'kubectl -n <namespace> get pods'.

## Post-install kibana setup.

get the pod name for your kibana instance (not the one set up with fluent-bit), and
kubectl -n <namespace> port-forward <pod_name> 5601:5601

go to 127.0.0.1:5601 in your web browser.

click on 'discover'.
use 'kubernetes_cluster-*' as the Index pattern.
click on 'Next step'
click on the 'Time Filter field name' dropdown, and select '@timestamp'.
click on 'create index patern'.

## Usage:

get the pod name for your kibana instance (not the one set up with fluent-bit), and
kubectl -n <namespace> port-forward <pod_name> 5601:5601

go to 127.0.0.1:5601 in your web browser.

click on 'discover' to view data.

## Nuking it all.

Find the names of the helm deploys for your pods (look at `helm ls` and `kubectl -n <namespace> get pods` , and run `helm del <helm_deploy_name>` for each of them.

Note: Elasticsearch does not use the name of the helm chart, and therefore is harder to identify.

## Debugging
kubectl -n <namespace> logs alternating-greyhound-fluent-bit-6lqr

# How this was developed:
first, we deployed elasticsearch with the elasticsearch-ephemeral chart, then kibana. then we deployed fluent-bit, which set up a kibana of it's own that looks broken. it had a kibana .tgz in an incorrect location, it also set up way more VMs than I thought, AND consumed the logs for the entire cluster, Rather than for the namespace it's contained in, as I expected. 

For kibana and fluent-bit, we created a shell of overides, with a dependency on the actual chart, so that when we helm dep update, helm grabs the chart from upstream, instead of bringing the source of the chart into our repository.
There were only three files to modify, which we copied from the fake-aws-s3 chart and modified: Chart.yaml, requirements.yaml, and values.yaml.

For elasticsearch, we bumped the version number, because kibana was refusing to start, citing too old of a version of elasticsearch. it wants a 6.x, we use 5.x for brig, and for our kibana/logserver setup.

