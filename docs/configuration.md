# Configuration

This contains instructions towards a more production-ready setup. Depending on your use-case and requirements, you may only need to configure a subset of the following sections.

<!-- vim-markdown-toc GFM -->

* [Additional requirements recommended for a production setup](#additional-requirements-recommended-for-a-production-setup)
* [Prelude: Overriding configuration settings](#prelude-overriding-configuration-settings)
* [Configuring](#configuring)
    * [SMTP server](#smtp-server)
    * [Load balancer on bare metal servers](#load-balancer-on-bare-metal-servers)
    * [Load Balancer on cloud-provider](#load-balancer-on-cloud-provider)
    * [Real AWS services](#real-aws-services)
    * [Persistence and high-availability](#persistence-and-high-availability)
    * [Security](#security)
    * [Sign up with a phone number (Sending SMS)](#sign-up-with-a-phone-number-sending-sms)
    * [3rd-party proxying](#3rd-party-proxying)
    * [TURN servers (Audio/Video calls)](#turn-servers-audiovideo-calls)
    * [Metrics/logging](#metricslogging)

<!-- vim-markdown-toc -->

# Additional requirements recommended for a production setup

* more server resources to ensure [high-availability](#persistence-and-high-availability)
* an email/SMTP server to send out registration emails
* depending on your required functionality, you may or may not need an [**AWS account**](https://aws.amazon.com/). See details about limitations without an AWS account in the following sections.
* one or more people able to maintain the installation
* official support by Wire ([contact us](https://wire.com/pricing/))

# Prelude: Overriding configuration settings

In case you're unfamiliar with the [helm documentation](https://docs.helm.sh/)

1. Default values are under a specific chart's `values.yaml` file, e.g. `charts/brig/values.yaml`
2. If a chart uses sub charts, there can be overrides in the parent chart's `values.yaml` file, if namespaced to the sub chart. Example: if chart `parent` includes chart `child`, and `child`'s `values.yaml` has a default value `foo: bar`, and the `parent` chart's `values.yaml` has a value
    ```
    child:
      foo: baz
    ```
    then the value that will be used is `baz`.
3. Values passed to helm via `-f <filename>` override the above. Note that if you `helm install parent` but wish to override values for `child`, the same logic as in `2.` applies. If `-f <filename>` is used multiple times, the last file wins in case keys exist multiple times (there is no merge performed).

# Configuring

## SMTP server

**Assumptions**: none

**Provides**:

* full control over email sending

**You need**:

* SMTP credentials (to allow for email sending; prerequisite for registering users and running the smoketest)

**How to configure**:

* *if using a gmail account, ensure to enable ['less secure apps'](https://support.google.com/accounts/answer/6010255?hl=en)*
* Add user, SMTP server, connection type to `values/wire-server`'s values file under `brig.config.smtp`
* Add password in `secrets/wire-server`'s secrets file under `brig.secrets.smtpPassword`

## Load balancer on bare metal servers

**Assumptions**:

* You installed kubernetes on bare metal servers or virtual machines that can bind to a public IP address.
* **If you are using AWS or another cloud provider, see [Creating a cloudprovider-based load balancer](#load-balancer-on-cloud-provider) instead**

**Provides**:

* Allows using a provided Load balancer for incoming traffic
* SSL termination is done on the ingress controller
* You can access your wire-server backend with given DNS names, over SSL and from anywhere in the internet

**You need**:

* A kubernetes node with a _public_ IP address (or internal, if you do not plan to expose the Wire backend over the Internet but we will assume you are using a public IP address)
* DNS records for the different exposed addresses (the ingress depends on the usage of virtual hosts), namely:
  * bare-https.your-domain
  * bare-ssl.your-domain
  * bare-s3.your-domain
  * bare-webapp.your-domain
  * bare-team.your-domain (optional)
* A wildcard certificate for the different hosts (*.your-domain) - we assume you want to do SSL termination on the ingress controller

**Caveats**:

* Note that there can be only a _single_ load balancer, otherwise your cluster might become [unstable](https://metallb.universe.tf/installation/)

**How to configure**:

```
cp values/metallb/demo-values.example.yaml values/metallb/demo-values.yaml
cp values/nginx-lb-ingress/demo-values.example.yaml values/nginx-lb-ingress/demo-values.yaml
cp values/nginx-lb-ingress/demo-secrets.example.yaml values/nginx-lb-ingress/demo-secrets.yaml
```

* Adapt `values/metallb/demo-values.yaml` to provide a list of public IP address CIDRs that your kubernetes nodes can bind to.
* Adapt `values/nginx-lb-ingress/demo-values.yaml` with correct URLs
* Put your TLS cert and key into `values/nginx-lb-ingress/demo-secrets.yaml`.

Install `metallb` (for more information see the [docs](https://metallb.universe.tf)):

```sh
./bin/update.sh metallb
helm upgrade --install --namespace metallb-system metallb charts/metallb \
    -f values/metallb/demo-values.yaml \
    --wait --timeout 1800
```

Install `nginx-lb-ingress`:

```
./bin/update.sh nginx-lb-ingress
helm upgrade --install --namespace demo nginx-lb-ingress charts/nginx-lb-ingress \
    -f values/nginx-lb-ingress/demo-values.yaml \
    -f values/nginx-lb-ingress/demo-secrets.yaml \
    --wait
```

Now, create DNS records for the URLs configured above.

## Load Balancer on cloud-provider

This information is not yet available. If you'd like to contribute by adding this information for your cloud provider, feel free to read the [contributing guidelines](../CONTRIBUTING.md) and open a PR.

## Real AWS services

**Assumptions**:

* You installed kubernetes and wire-server on AWS

**Provides**:

* Better availability guarantees and possibly better functionality of AWS services such as SQS and dynamoDB.
* You can use ELBs in front of nginz for higher availability.
* instead of using a smtp server and connect with SMTP, you may use SES. See configuration of brig and the `useSES` toggle.

**You need**:

* An AWS account

**How to configure**:

* Instead of using fake-aws charts, you need to set up the respective services in your account, create queues, tables etc. Have a look at the fake-aws-* charts; you'll need to replicate a similar setup.
    * Once real AWS resources are created, adapt the configuration in the values and secrets files for wire-server to use real endpoints and real AWS keys. Look for comments including `if using real AWS`.
* Creating AWS resources in a way that is easy to create and delete could be done using either [terraform](https://www.terraform.io/) or [pulumi](https://pulumi.io/). If you'd like to contribute by creating such automation, feel free to read the [contributing guidelines](../CONTRIBUTING.md) and open a PR.

## Persistence and high-availability

Currently, due to the way kubernetes and cassandra [interact](https://github.com/kubernetes/kubernetes/issues/28969), cassandra cannot reliably be installed on kubernetes. Some people have tried, e.g. [this project](https://github.com/instaclustr/cassandra-operator) though at the time of writing (Nov 2018), this does not yet work as advertised. We recommend therefore to install cassandra, (possibly also elasticsearch and redis) separately, i.e. outside of kubernetes (using 3 nodes each).

For further higher-availability:

* scale your kubernetes cluster to have separate etcd and master nodes (3 nodes each)
* use 3 instead of 1 replica of each wire-server chart

## Security

The bare minimum:

* Ensure traffic between kubernetes nodes, etcd and databases are confined to a private network
* Ensure kubernetes API is unreachable from the public internet (put behind VPN/bastion host)
* Ensure your operating systems get security updates automatically
* Restrict ssh access / harden sshd configuration
* Ensure no other pods with public access than the main ingress are deployed on your cluster, since, in the current setup, pods have access to etcd values (and thus any secrets stored there, including secrets from other pods)
* Ensure developers encrypt any secrets.yaml files

## Sign up with a phone number (Sending SMS)

**Provides**:

* Registering accounts with a phone number

**You need**:

* a [Nexmo](https://www.nexmo.com/) account
* a [Twilio](https://www.twilio.com/) account

**How to configure**:

See the `brig` chart for configuration.

## 3rd-party proxying

You need Giphy/Google/Spotify/Soundcloud API keys (if you want to support previews by proxying these services)

See the `proxy` chart for configuration.

## TURN servers (Audio/Video calls)

Not yet supported.

## Metrics/logging

Not yet supported
