# SFTD on kubernetes

## Preparing nodes in your cluster to host sftd

The sftd component is a bit special compared to other wire services, in that it
needs access to the host network. This is because it allocates UDP ports on
your public interface so that people can set up calls with the SFT.

Not all your nodes in your cluster might have a public IP. Currently the code
is set up such that the sftd components only run on nodes that have been
labelled to support it.

Within one sftd deployment, kubernetes will make sure that no two sftd pods
will run on the same node to avoid port allocation conflicts.

However, kubernetes can not guarantee that two _separate_ sftd deployments (for
example staging and prod) are not scheduled on the same node.  It is thus
important that if you have multiple sftd deployments that they run on a
disjoint set of nodes.

In our example we have two environments, `staging` and `prod`.  And thus we
create create node groups.


```
kubectl label node node-0 wire.com/role=sftd-prod
kubectl label node node-1 wire.com/role=sftd-prod
kubectl label node node-2 wire.com/role=sftd-prod

kubectl label node node-3 wire.com/role=sftd-staging
kubectl label node node-4 wire.com/role=sftd-staging
```

Or set them in your [ansible inventory](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/vars.md#other-service-variables):

```
node-0 node_labels="wire.com/role=sftd-prod"
node-1 node_labels="wire.com/role=sftd-prod"
node-2 node_labels="wire.com/role=sftd-prod"

node-3 node_labels="wire.com/role=sftd-staging"
node-4 node_labels="wire.com/role=sftd-staging"
```

If you look in `overlays/prod/statefulset.yaml` you see that we configure `sftd` to
only run on nodes with label `wire.com/role=sftd-prod`. Similarly for the `overlays/staging` setup.
```
...
      nodeSelector:
        wire.com/role: sftd-prod
...
```

## Configuring SFTD

### Ingress

in `overlays/{prod,staging}/ingress.yaml` you should set the domain name on
which `sftd`'s https API shoud be reachable for clients by setting the
`wire.com/ingress-host` annotation on the `Ingress`

### Certificates

If you have cert-manager running in your cluster, this example will
automatically issue certificates for the SFT.  You should make sure that
the `cert-manager.io/cluster-issuer` matches the name of the `ClusterIssuer` that
you have deployed in your cluster.

You can remove automatic certificate issuance by removing the
`cert-manager.io/cluster-issuer` annotation from the `Ingress` completely.  You
should then provide your own TLS certificate manually. You can do this by
adding the following section to the environment's `kustomization.yaml`:
```yaml
secretGenerator:
  - name: sftd-tls
    type: kubernetes.io/tls
    files:
      - path/to/tls.crt
      - path/to/tls.key
```

## Replicas and resources
You should make sure that the number of replicas on the `sftd` statefulset is
not more than the amount of nodes with the `sftd` role.  Only one `sftd` pod
can be scheduled per node.

Resource limits can be set on a per-environment basis too. We do not have
recommended values for these yet so we leave them unset for now.

# Deploy

Once you have configured everything a deploy can simply be done with `kubectl`:

For staging:
```
$ kubectl apply -k ./overlays/staging
```

For prod:
```
$ kubectl apply -k ./overlays/prod
```

To delete the deployment:
```
kubectl delete -k ./overlays/staging
```
