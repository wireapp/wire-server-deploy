Kubecfg/jsonnet-based automation for Wire
=========================================

TODO(serge): move this to real documentation - this is temporary until it's merged to master

Install kubecfg and jsonnet
---------------------------

For jsonnet, install it from your package manager.

For kubecfg:

    go get github.com/bitnami/kubecfg

`$GOPATH/bin` must be in your `$PATH`. By default, `$GOPATH` is `$HOME/go/bin`.

Configure your cluster
----------------------

Once you have a Wire deployment on Kubernetes, you will need to let this automation know about it.

At some point, this will be the one and only step to actually deploy Wire.

For that, edit `deployments.libsonnet`, and add your deployment, basing it on the `example` deployment. See `deployments.libsonnet` for information about configurable fields.

Deploy/update
-------------

    kubecfg diff --diff-strategy=subset top-kubecfg.jsonnet
    kubecfg update top-kubecfg.jsonnet

Extra
-----

We also, as an example, show that the jsonnet codebase can emit more than just kubernetes configs.

For example, we have some machinery for services to declare what nginz routes they want. To view the 'synthesized'
output of those routes, do:

    jsonnet eval top-nginz.jsonnet

This would be, in practice, consumed by a specialized tool, for instance one that emits nginz configuration (if nginz is not controlled via this codebase, eg. is configured via Helm).
