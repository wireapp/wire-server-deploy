### What does this wrapper chart do?

* configure a *ClusterIssuer* to issue ACME HTTP01 certificates provided by Letsencrypt
* create a dedicated namespace for *cert-manager* resources and configurations
* install CDRs required by *cert-manager*, instead of the [options mentioned in the docs](https://cert-manager.io/docs/installation/kubernetes/#steps)
  Why? See https://github.com/jetstack/cert-manager/issues/2961


### Chart lifecycle

__Install:__ as a sub-chart, usually there is nothing to do, other than
[providing/overriding](https://helm.sh/docs/chart_template_guide/subcharts_and_globals/#overriding-values-from-a-parent-chart) values.

__Update:__ As of now, Helm
[doesn't support updating nor deleting CRDs](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/#install-a-crd-declaration-before-using-the-resource).
So, whenever those change, they have to be removed manually before running `helm upgrade` or updated by hand using 
`kubectl appply -f https://github.com/jetstack/cert-manager/releases/download/v${version}/cert-manager-legacy.crds.yaml`.

__Delete:__ Aside from the usual `helm uninstall` it is also required to remove the namespace created for *cert-manager*
as well as removing all CRDs (`*.cert-manager.io`).


### Todo when introducing support for K8s >= 1.15 

* `./crds/cert-manager-v${version}-legacy.crds.yaml` has to be replaced by the set of CRDs that support
  `cert-manager.io/v1alpha3` instead of `cert-manager.io/v1alpha2`, which can be found here:
  `https://github.com/jetstack/cert-manager/releases/download/v${version}/cert-manager.crds.yaml`
* the `apiVersion` of all resources based on those CRD, namely `./templates/cluster-issuer.yaml` and 
  `./../nginx-ingress-services/templates/certificate.yaml`, has to be changed to `cert-manager.io/v1alpha3`


### Monitoring

__FUTUREWORK:__ When `wire-server-metrics` is ready, expiration & renewal should be integrated into monitoring.
