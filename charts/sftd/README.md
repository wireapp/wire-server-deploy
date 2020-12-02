# SFTD Chart

## Deploy


Using your own certificates:

```
helm install sftd charts/std --set host=example.com --set-file tls.crt=/path/to/tls.crt --set-file tls.key=/path/to/tls.key
```

Using Cert-manager:
```
helm install sftd charts/std --set host=example.com --set tls.issuerRef.name=letsencrypt-staging
```

You can switch between `cert-manager` and own-provided certificates at any
time. Helm will delete the `sftd` secret automatically and then cert-manager
will create it instead.


## DNS

An SRV record needs to be present for the domain name defined in `host`.
This is an artifact of the fact the wire backend currently uses public SRV
records for service discovery. The record needs to be of the form:

```
_sft._tcp.{{ .Values.host }}  {{ .Values.host }} 443
```

## Multiple sftd deployments in a single cluster
Because sftd uses the `hostNetwork` and binds to the public IP of the node,
there can only be one `sftd` pod running per node in the cluster.  Within a
single `StatefulSet` kubernetes will make sure no two pods are scheduled on the
same machine automatically. However, if you have multiple `sftd` deployments under
different releases names or in a different namespace more care has to be taken.

You can set the `nodeSelector` option; to make sure your sftd releases run on disjoint sets of nodes.

For example, consider the following inventory of nodes, where there are two groups
annotated with

```
[sftd-prod:vars]
node_labels="wire.com/role=sftd-prod"
[sftd-staging:vars]
node_labels="wire.com/role=sftd-staging"

[sftd-prod]
node0
node1
node3

[sftd-staging]
node4
```

Then we can make two `sftd` deployments and make sure Kubernetes schedules them on distinct set of nodes:

```
helm install sftd-prod charts/sftd    --set 'nodeSelector.wire\.com/role=sftd-prod' ...other-flags
helm install sftd-staging charts/sftd --set 'nodeSelector.wire\.com/role=sftd-staging' ...other-flags
```





