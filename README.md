# Wire™

[![Wire logo](https://github.com/wireapp/wire/blob/master/assets/header-small.png?raw=true)](https://wire.com/jobs/)

This repository is part of the source code of Wire. You can find more information at [wire.com](https://wire.com) or by contacting opensource@wire.com.

You can find the published source code at [github.com/wireapp/wire](https://github.com/wireapp/wire).

For licensing information, see the attached [LICENSE](LICENSE) file and the list of third-party licenses at [wire.com/legal/licenses/](https://wire.com/legal/licenses/).

No license is granted to the Wire trademark and its associated logos, all of which will continue to be owned exclusively by Wire Swiss GmbH. Any use of the Wire trademark and/or its associated logos is expressly prohibited without the express prior written consent of Wire Swiss GmbH.

## Introduction

This repository contains code and documentation on how to deploy [wire-server](https://github.com/wireapp/wire-server). To allow a maximum of flexibility with respect to where wire-server can be deployed (e.g. with cloud providers like AWS, on bare-metal servers, etc), we chose [kubernetes](https://kubernetes.io/) as the target platform.

This means you first need to install a kubernetes cluster, and then deploy wire-server onto that kubernetes cluster.

<!-- vim-markdown-toc GFM -->

* [Status](#status)
* [Prerequisites](#prerequisites)
    * [Required server resources](#required-server-resources)
* [Contents of this repository](#contents-of-this-repository)
* [Development setup](#development-setup)
* [Installing wire-server](#installing-wire-server)
    * [Demo installation](#demo-installation)
        * [Install non-persistent, non-highly-available databases](#install-non-persistent-non-highly-available-databases)
        * [Install AWS service mocks](#install-aws-service-mocks)
        * [Install a demo SMTP server](#install-a-demo-smtp-server)
        * [Install wire-server](#install-wire-server)
        * [Adding a load balancer, DNS, and SSL termination](#adding-a-load-balancer-dns-and-ssl-termination)
        * [Beyond the demo](#beyond-the-demo)
    * [Support with a production on-premise (self-hosted) installation](#support-with-a-production-on-premise-self-hosted-installation)
* [Monitoring](#monitoring)
* [Troubleshooting](#troubleshooting)

<!-- vim-markdown-toc -->

## Status

Code in this repository should be considered **alpha**. We do not (yet) run our production infrastructure on kubernetes.

Supported features:

- wire-server (API)
    - [x] user accounts, authentication, conversations
    - [x] assets handling (images, files, ...)
    - [x] (disabled by default) 3rd party proxying
    - [x] notifications over websocket
    - [ ] notifications over [FCM](https://firebase.google.com/docs/cloud-messaging/)/[APNS](https://developer.apple.com/notifications/) push notifications
    - [ ] audio/video calling ([TURN](https://en.wikipedia.org/wiki/Traversal_Using_Relays_around_NAT)/[STUN](https://en.wikipedia.org/wiki/STUN) servers using [restund](https://github.com/wireapp/restund))
- wire-webapp
    - [x] fully functioning web client (like `https://app.wire.com`)
- wire-team-settings
    - [x] team management (including invitations, requires access to a private repository)
- wire-account-pages
    - [x] user account management (password reset, requires access to a private repository)


## Prerequisites

As a minimum for a demo installation, you need:

* a **Kubernetes cluster** with enough resources. There are [many different options](https://kubernetes.io/docs/setup/pick-right-solution/). A tiny subset of those solutions we tried include:
    * if using AWS, you may want to look at:
        * [EKS](https://aws.amazon.com/eks/) (if you're okay having all your data in one of the EKS-supported US regions)
        * [kops](https://github.com/kubernetes/kops)
    * if using regular physical or virtual servers:
        * [kubespray](https://github.com/kubernetes-incubator/kubespray)
* a **Domain Name** under your control and the ability to set DNS entries
* the ability to generate **SSL certificates** for that domain name
    * you could use e.g. [Let's Encrypt](https://letsencrypt.org/)

### Required server resources

* For an ephemeral in-memory demo-setup
    * a single server with 8 CPU cores, 32GB of memory, and 20GB of disk space is sufficient.
* For a production setup, you need at least 3 servers. For an optimal setup, more servers are required, it depends on your environment.

## Contents of this repository

* `bin/` - some helper bash scripts
* `charts/` - so-called "[helm](https://www.helm.sh/) charts" - templated kubernetes configuration in YAML
* `docs/` - further documentation
* `values/` - example override values to helm charts

## Development setup

You need to install

* [helm](https://docs.helm.sh/using_helm/#installing-helm) (v2.11.x is known to work)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (v1.12.x is known to work)

and you need to configure access to a kubernetes cluster (minimum v1.9+, 1.12+ recommended).

Optionally, if working in a team and you'd like to share `secrets.yaml` files between developers using a private git repository and encrypted files, you may wish to install

* [sops](https://github.com/mozilla/sops)
* [helm-secrets plugin](https://github.com/futuresimple/helm-secrets)

## Installing wire-server

### Demo installation

* AWS account not required
* Requires only a kubernetes cluster

The demo setup is the easiest way to install a functional wire-server with limitations (such as no persistent storage, no high-availability, missing features). For the purposes of this demo, we assume you **do not have an AWS account**. Try this demo first before trying to configure a more complicated setup involving persistence and higher availability.

Get charts from wire's s3 repo:

```shell
helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
```

(Alternatively, you can run replace `wire/<chart>` with `charts/<chart>` in all subsequent commands.  This will read charts from your local file system.  Make sure your working directory is the root of this repo, and that after changing any of the chart files, you run `./bin/update.sh` on them.)

*For all the following `helm upgrade` commands, it can be useful to run a second terminal with `kubectl --namespace demo get pods -w` to see what's happening.*

#### Install non-persistent, non-highly-available databases

*Please note that this setup is for demonstration purposes; no data is ever written to disk, so a restart will wipe data. Even without restarts expect it to be unstable: you may experience total service unavailability and/or **total data loss after a few hours/days** due to the way kubernetes and cassandra [interact](https://github.com/kubernetes/kubernetes/issues/28969). For more information on this see the production installation section.*

The following will install (or upgrade) 3 single-pod databases and 3 ClusterIP services to reach them:

- **databases-ephemeral**
    - cassandra-ephemeral
    - elasticsearch-ephemeral
    - redis-ephemeral

```shell
helm upgrade --install --namespace demo demo-databases-ephemeral wire/databases-ephemeral --wait
```

To delete: `helm delete --purge demo-databases-ephemeral`

#### Install AWS service mocks

The code in wire-server still depends on some AWS services for some of its functionality. To ensure wire-server services can correctly start up, install the following "fake" (limited-functionality, non-HA) aws services:

- **fake-aws**
    - fake-aws-sqs
    - fake-aws-sns
    - fake-aws-s3
    - fake-aws-dynamodb

```shell
helm upgrade --install --namespace demo demo-fake-aws wire/fake-aws --wait
```

To delete: `helm delete --purge demo-fake-aws`

#### Install a demo SMTP server

You can either install this very basic SMTP server, or configure your own (see SMTP options in [this section](docs/configuration.md#smtp-server))

```shell
helm upgrade --install --namespace demo demo-smtp wire/demo-smtp --wait
```

#### Install wire-server

- **wire-server**
    - cassandra-migrations
    - elasticsearch-index
    - galley
    - gundeck
    - brig
    - cannon
    - nginz
    - proxy (optional, disabled by default)
    - spar (optional, disabled by default)
    - webapp (optional, enabled by default)
    - team-settings (optional, disabled by default - requires access to a private repository)
    - account-pages (optional, disabled by default - requires access to a private repository)

Start by copying the necessary `values` and `secrets` configuration files:

```
cp values/wire-server/demo-values.example.yaml values/wire-server/demo-values.yaml
cp values/wire-server/demo-secrets.example.yaml values/wire-server/demo-secrets.yaml
```

In `values/wire-server/demo-values.yaml` (referred to as `values-file` below) and `values/wire-server/demo-secrets.yaml` (referred to as `secrets-file`), the following has to be adapted:

* turn server shared key (needed for audio/video calling)
    * Generate with e.g. `openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42` or similar
    * Add key to secrets-file under `brig.secrets.turn.secret`
    * (this will eventually need to be shared with a turn server, not part of this demo yet)
* zauth private/public keys (For authentication; `access tokens` and `user tokens` (cookies) are signed and validated with these)
    * Generate from within [wire-server](https://github.com/wireapp/wire-server) with `./dist/zauth -m gen-keypair -i 1` if you have everything compiled; or alternatively with docker using `docker run --rm quay.io/wire/alpine-intermediate /dist/zauth -m gen-keypair -i 1`
    * add both to secrets-file under `brig.zauth` and the public one to secrets-file under `nginz.secrets.zAuth.publicKeys`
* domain names and urls
    * in your values-file, replace `example.com` and other domains and subdomains with domains of your choosing. Look for the `# change this` comments. You can try using `sed -i 's/example.com/<your-domain>/g' <values-file>`.

Try linting your chart, are any configuration values missing?

```sh
helm lint -f values/wire-server/demo-values.yaml -f values/wire-server/demo-secrets.yaml wire/wire-server
```

If you're confident in your configuration, try installing it:

```sh
helm upgrade --install --namespace demo demo-wire-server wire/wire-server \
    -f values/wire-server/demo-values.yaml \
    -f values/wire-server/demo-secrets.yaml \
    --wait
```

If pods fail to come up the `helm upgrade` may fail or hang; you may wish to run `kubectl get pods -n demo -w` to
see which pods are failing to initialize. Describing the pods may provide information as to why they're failing to
initialize.

If installation fails you may need to delete the release `helm delete --purge demo-wire-server` and try again.

#### Adding a load balancer, DNS, and SSL termination

* If you're on bare metal or on a cloud provider without external load balancer support, see [configuring a load balancer on bare metal servers](docs/configuration.md#load-balancer-on-bare-metal-servers)
* If you're on AWS or another cloud provider, see [configuring a load balancer on cloud provider](docs/configuration.md#load-balancer-on-cloud-provider)

#### Beyond the demo

For further configuration options (some have specific requirements about your environment), see [docs/configuration.md](docs/configuration.md).

### Support with a production on-premise (self-hosted) installation

[Get in touch](https://wire.com/pricing/).

## Monitoring

See the [monitoring guide](./docs/monitoring.md)

## Troubleshooting

There are multiple artifacts which combine to form a running wire-server deployment; these include:
- docker images for each service
- kubernetes configs for each deployment (from helm charts)
- configuration maps for each deployment (from helm charts)


If you wish to get some information regarding the code currently running on your cluster you can run the following:

```
./bin/deployment-info.sh <namespace> <deployment-name (e.g. brig)>
```

Example run:

```
./deployment-info.sh demo brig
docker_image:               quay.io/wire/brig:2.50.319
chart_version:              wire-server-0.24.9
wire_server_commit:         8ec8b7ce2e5a184233aa9361efa86351c109c134
wire_server_link:           https://github.com/wireapp/wire-server/releases/tag/image/2.50.319
wire_server_deploy_commit:  01e0f261ca8163e63860f8b2af6d4ae329a32c14
wire_server_deploy_link:    https://github.com/wireapp/wire-server-deploy/releases/tag/chart/wire-server-0.24.9
```

Note you'll need `kubectl`, `git` and `helm` installed


It will output the running docker image; the corresponding wire-server commit hash (and link) and the wire-server helm
chart version which is running.
