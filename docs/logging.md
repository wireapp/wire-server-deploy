# Deploying logging for the staging cluster:

## Deploying ElasticSearch
```
$ helm install --namespace <namespace> wire/elasticsearch-ephemeral/
```

Note that since we are not specifying a release name during helm install, it generates a 'verb-noun' pair, and uses it.
Elasticsearch's chart does not use the release name of the helm chart in the pod name, sadly.


## Deploying Kibana
```
$ helm install --namespace <namespace> wire/kibana/
```

Note that since we are not specifying a release name during helm install, it generates a 'verb-noun' pair, and uses it. If you look at your pod names, you can see this name prepended to your pods in 'kubectl -n <namespace> get pods'.

## Deploying fluent-bit
```
$ helm install --namespace <namespace> wire/fluent-bit/
```

Alternately, if there is already fluent-bit deployed in your environment, get the helm name for the deployment (verb-noun prepended to the pod name), and
```
$ helm upgrade <helm-name> --namespace <namespace> wire/fluent-bit/
```

Note that since we are not specifying a release name during helm install, it generates a 'verb-noun' pair, and uses it. if you look at your pod names, you can see this name prepended to your pods in 'kubectl -n <namespace> get pods'.

## Post-install kibana setup.

Get the pod name for your kibana instance (not the one set up with fluent-bit), and
```
$ kubectl -n <namespace> port-forward <pod_name> 5601:5601
```

go to 127.0.0.1:5601 in your web browser.

1. Click on 'discover'.
2. Use 'kubernetes_cluster-*' as the Index pattern.
3. Click on 'Next step'
4. Click on the 'Time Filter field name' dropdown, and select '@timestamp'.
5. Click on 'create index patern'.

## Usage:

Get the pod name for your kibana instance (not the one set up with fluent-bit), and
```
$ kubectl -n <namespace> port-forward <pod_name> 5601:5601
```

Go to 127.0.0.1:5601 in your web browser.

Click on 'discover' to view data.

## Nuking it all.

Find the names of the helm releases for your pods (look at `helm ls` and `kubectl -n <namespace> get pods` , and run `helm del <helm_deploy_name> --purge` for each of them.

Note: Elasticsearch does not use the name of the helm chart, and therefore is harder to identify.

## Debugging
```
kubectl -n <namespace> logs <host>
```

# How this was developed:
First, we deployed elasticsearch with the elasticsearch-ephemeral chart, then kibana. then we deployed fluent-bit, which set up a kibana of it's own that looks broken. It had a kibana .tgz in an incorrect location. It also set up way more VMs than I thought, AND consumed the logs for the entire cluster, Rather than for the namespace it's contained in, as I expected. 

For kibana and fluent-bit, we created a shell of overides, with a dependency on the actual chart, so that when we helm dep update, helm grabs the chart from upstream, instead of bringing the source of the chart into our repository.
There were only three files to modify, which we copied from the fake-aws-s3 chart and modified: Chart.yaml, requirements.yaml, and values.yaml.

For elasticsearch, we bumped the version number, because kibana was refusing to start, citing too old of a version of elasticsearch. it wants a 6.x, we use 5.x for brig, and for our kibana/logserver setup. later, we forced integration tests against the new elasticsearch in confluence.

