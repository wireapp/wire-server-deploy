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
* [Development setup](#development-setup)
* [Installing wire-server](#installing-wire-server)
    * [Demo installation](#demo-installation)
        * [Install non-persistent, non-highly-available databases](#install-non-persistent-non-highly-available-databases)
        * [Install AWS service mocks](#install-aws-service-mocks)
        * [Install wire-server](#install-wire-server)
    * [Demo installation with real AWS](#demo-installation-with-real-aws)
    * [Production on-premise installation](#production-on-premise-installation)

<!-- vim-markdown-toc -->

## Status

Code in this repository should be considered **alpha**. We do not (yet) run our production infrastructure on kubernetes.

## Prerequisites

You need:

* a **Kubernetes cluster** with enough resources. There are [many different options](https://kubernetes.io/docs/setup/pick-right-solution/). A tiny subset of those solutions we tried include:
    * if using AWS, you may want to look at:
        * [EKS](https://aws.amazon.com/eks/) (if you're okay having all your data in one of the EKS-supported US regions)
        * [kops](https://github.com/kubernetes/kops)
    * if using regular physical or virtual servers:
        * [kubespray](https://github.com/kubernetes-incubator/kubespray)
* a **Domain Name** under your control and the ability to set DNS entries
* the ability to generate **SSL certificates** for that domain name
    * you could use e.g. [Let's Encrypt](https://letsencrypt.org/)
* an email server (allowing SMTP) to send out registration emails
* depending on your required functionality, you may or may not need an [**AWS account**](https://aws.amazon.com/). See details about limitations without an AWS account in the following sections.

### Required server resources

* For an ephemeral in-memory demo-setup
    * a single server with 8 CPU cores, 32GB of memory, and 20GB of disk space is sufficient.
* For a production setup, you need at least 3 servers. For an optimal setup, more servers are required, it depends on your environment.

## Development setup

You need to install

* [GNU make](https://www.gnu.org/software/make/)
* [helm](https://docs.helm.sh/using_helm/#installing-helm)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

and you need to configure access to a kubernetes cluster.

Optionally, if working in a team and you'd like to share `secrets.yaml` files between developers using a private git repo and encrypted files, you may wish to install

* [sops](https://github.com/mozilla/sops)
* [helm-secrets plugin](https://github.com/futuresimple/helm-secrets)

## Installing wire-server

Supported features:

- wire-server (API)
    - [x] user accounts, authentication, conversations
    - [x] assets handling (images, files, ...)
    - [x] (disabled by default) 3rd party proxying
    - [x] notifications over websocket
    - [ ] notifications over FCM/APNS push notifications
    - [ ] audio/video calling
- wire-webapp
    - [ ] ...

### Demo installation

* AWS account not required
* limited functionality
* Requires only a kubernetes cluster

The demo setup is the easiest way to install a functional wire-server with limitations (such as no persistent storage, no high-availability, missing features). For the purposes of this demo, we assume you **do not have an AWS account**. Try this demo first before trying to configure a more complicated setup involving persistence and higher availability.

*For all the following `helm upgrade` commands, it can be useful to run a second terminal with `kubectl --namespace demo get pods -w` to see what's happening.*

#### Install non-persistent, non-highly-available databases

*Please note that this setup is for demonstration purposes; no data is ever written to disk, so a restart will wipe data. Even without restarts expect it to be unstable: you may experience total service unavailability and/or **total data loss after a few hours/days** due to the way kubernetes and cassandra [interact](https://github.com/kubernetes/kubernetes/issues/28969). For more information on this see the production installation section.*

The following will install (or upgrade) 3 single-pod databases and 3 ClusterIP services to reach them:

- **databases-ephemeral**
    - cassandra-ephemeral
    - elasticsearch-ephemeral
    - redis-ephemeral

```shell
./bin/update.sh databases-ephemeral # a recursive wrapper around 'helm dep update'
helm upgrade --install --namespace demo demo-databases-ephemeral charts/databases-ephemeral --wait
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
./bin/update.sh fake-aws # a recursive wrapper around 'helm dep update'
helm upgrade --install --namespace demo demo-fake-aws charts/fake-aws --wait
```

To delete: `helm delete --purge demo-fake-aws`

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

Start by copying the necessary configuration files:

```
cp values/demo-values.example.yaml values/demo-values.yaml
cp values/demo-secrets.example.yaml values/demo-secrets.yaml
```

In `values/demo-values.yaml` (referred to as `values` file below) and `values/demo-secrets.yaml` (referred to as `secrets` file), the following has to be adapted:

* smtp credentials (to allow for email sending; prerequisite for registering users and running the smoketest)
    * *if using a gmail account, ensure to enable ['less secure apps'](https://support.google.com/accounts/answer/6010255?hl=en)*
    * Add user, smtp server, connection type in values/`brig.config.smtp`
    * Add password in secrets/`brig.secrets.smtpPassword`
* turn server shared key (needed for audio/video calling)
    * Generate with e.g. `openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42` or similar
    * Add value to secrets/`brig.secrets.turn.secret`
    * (this will eventually need to be shared with a turn server, not part of this demo yet)
* zauth private/public keys (For authentication; `access tokens` and `user tokens` (cookies) are signed and validated with these)
    * Generate from within [wire-server](https://github.com/wireapp/wire-server) with `./dist/zauth -m gen-keypair -i 1` if you have everything compiled; or alternatively with docker using `docker run --rm quay.io/wire/alpine-intermediate /dist/zauth -m gen-keypair -i 1`
    * add both to secrets/`brig.zauth` and the public one to secrets/`nginz.secrets.zauth`
* domain names and urls
    * in `values`, replace `example.com` and other domains and subdomains with domains of your choosing. Look for the `# change this` comments.

Update the chart dependencies:

```sh
./bin/update.sh wire-server
```

Try linting your chart, are any configuration values missing?

```sh
helm lint -f values/demo-values.yaml -f values/demo-secrets.yaml charts/wire-server
```

If you're confident in your configuration, try installing it:

```sh
helm upgrade --install --namespace demo demo-wire-server charts/wire-server \
    -f values/demo-values.yaml \
    -f values/demo-secrets.yaml \
    --wait
```

### Demo installation with real AWS

see [docs/demo-AWS.md](docs/demo-AWS.md)

### Production on-premise installation

For the time being, get in touch. See [this page](https://wire.com/pricing/).

