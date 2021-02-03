# Helm-based deployment

The Wire platform is deployed on top of Kubernetes. This certainly includes all *stateless* services (e.g. Brig, Galley),
but may or may not include *stateful* backing services (e.g. Cassandra or Elasticsearch).

The respective Kubernetes objects are defined in Helm charts. This allows to template and transfer them. 
The charts themselves are defined in [wire-server](https://github.com/wireapp/wire-server/tree/master/charts)
and uploaded to the [release](https://s3-eu-west-1.amazonaws.com/public.wire.com/charts) or
[develop](https://s3-eu-west-1.amazonaws.com/public.wire.com/charts-develop) Helm repositories.

To describe a deployment in a declarative fashion a tool called [*Helmfile*](https://github.com/roboll/helmfile) is
being used, which wraps the `helm` CLI. 


## Deploy environment created by `terraform/environment`

An 'environment' is supposed to represent all the setup required for the Wire
platform to function.

'Deploying' an environment means creating the respective Objects on top of Kubernetes
to instantiate all the services that together represent the Wire backend. This action
can be re-run as often as you want (e.g. in case you change some variables or upgrade
to new versions).

To start with, the environment must contain a `helmfile.yaml` listing each *release*
(based on a chart) and repositories they depend on.

1. Please ensure `ENV_DIR` or `ENV` are exported as specified in the [docs in
   the terraform folder](../terraform/README.md)
1. Ensure that `make bootstrap` has been run to create a Kubernetes cluster
1. Ensure `$ENV_DIR/kubeconfig.dec` exists to authenticate against the kube-apiserver
   of the cluster in question. 
1. Running `make deploy` from this directory will bootstrap the
   environment.
