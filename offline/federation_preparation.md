# Configuring your Wire-server installation for federation

## Infrastructure

### DNS

To get started, you will need an A record for `federator` in addition to your current wire-server domains.
Each Wire instance also needs an SRV DNS record for federation to work (in addition to the ingress A record):

```
dig srv _wire-server-federator._tcp.example.com +short

0 10 443 federator.example.com.
```

### Networking (calling, mostly)

#### Federated Calling Traffic

In order for users on both federated backends to communicate, calling traffic needs to travel between your wire calling environment and the calling environment of your federation partner.

There are two options for how calling traffic is transfered between federating backends: with, or without DTLS.
If you have chosen DTLS, you need to have incoming port 9191 between your calling clusters. Federated calling traffic will be transmitted between federated environments on this port.

### Communications
If you decide to use the DTLS transport option for federated calling traffic, you will need a trusted communication channel with your federation partner, in order to handle key material.

## Services

**IMPORTANT:** In the following section you will be setting a *federation domain* for your Wire installation. This domain can never be changed during runtime, and uniquely identifies your installation, both to other federated partners, and to your end user's devices. Touching this domain requires deleting all history on all attached environments! Once this has been set, and you have redeployed `wire-server`, do not change it anymore!!!

### RabbitMQ

You can refer to [offline/rabbitmq_setup.md](https://github.com/wireapp/wire-server-deploy/blob/master/offline/rabbitmq_setup.md) for creating RabbitMQ cluster, if you haven't yet.

### Ingress

SSL certs for the federator ingress can either be acquired via cert-manager and Letsencrypt if enabled in the [nginx-ingress-service/values.yaml](../values/nginx-ingress-services/prod-values.example.yaml)
or added manually, see "Bring your own certificates" in [offline/docs_ubuntu_22.04.md](./docs_ubuntu_22.04.md)

Open `values/nginx-ingress-services/values.yaml`, add:

```yaml
federator:
  enabled: true
```

Uncomment federator in the domain list.

Get the latest root CA from your certificate provider in pem and use it as `secrets.tlsClientCA`.
NOTE: This is also required if you are using cert-manager!

```bash
d helm upgrade nginx-ingress-services charts/nginx-ingress-services/ -f values/nginx-ingress-services/values.yaml --set-file secrets.tlsClientCA=ca.pem
```

## Helm chart configuration

Open up your `values/wire-server/values.yaml` file and look for any federation related settings and enable or adjust accordingly. (`enableFederation`, `federationDomain`, `setFederationDomain`, `setFederationStrategy`, `setFederationDomainConfigs`)

```yaml
tags:
  federation: true
```

### Brig

```yaml
brig:
  config:
    enableFederation: true
    optSettings:
      setFederationDomain: example.com
      setFederationStrategy: allowDynamic # possible options: allowNone | allowAll | allowDynamic
      setFederationDomainConfigs:
        - domain: example2.com
          search_policy: full_search # possible options: no_search | exact_handle_search | full_search
```

#### setFederationStrategy

The 'setFederationStrategy' configuration option controls how your backend responds to federation requests from other backends. For more details, visit [docs.wire.com](https://docs.wire.com/understand/configure-federation.html#configure-federation-strategy-whom-to-federate-with-in-brig).

- allowNone - "disabled" federation
- allowAll - lets any BE federate (send requests to federator) 
- allowDynamic - only backends set in setFederationDomainConfigs can federate

#### setFederationDomainConfigs

The 'setFederationDomainConfigs' configuration option controls inbound user lookups and searches from other federated backends. For more details, visit [docs.wire.com](https://docs.wire.com/understand/configure-federation.html#configure-federation-strategy-whom-to-federate-with-in-brig).

- no_search - **default**, users can't be found with federated search
- exact_handle_search - users can only be found when the exact user handle is matched in the search
- full_search - users can be found even with a partial match to their user handle

### Cargohold

```yaml
cargohold:
  config:
    enableFederation: true
    settings:
      federationDomain: example.com
```

### Galley

```yaml
galley:
  config:
    enableFederation: true
    settings:
      federationDomain: example.com
```

### Federator

Depending on your chosen federation strategy, the same configuration should be set, as it was set in brig.
Either `allowAll` or a list in `allowedDomains`.

```yaml
federator:
  config:
    optSettings:
      federationStrategy:
        #allowAll: true
        #allowedDomains:
        #  - example2.com
        #  - example.org
```

### Background-worker

Append this section to the end of the `values/wire-server/values.yaml`

```yaml
background-worker:
  config:
    enableFederation: true
```

### Secrets

Important: `brig`, `galley` and `background-worker` need to be able to access RabbitMQ with the same secret.
These should be set in `values/wire-server/secrets.yaml`

Example:
```yaml
brig | galley | background-worker:
  secrets:
    rabbitmq:
      username: username
      password: password
```

## Calling

To begin with, you need to make a few decisions:
 * How paranoid am I (separation of sensitive content) -- Do I want separation between "local" calling traffic between my backend and it's users, from the calling traffic to and from a remote (trusted) backend?
 * How paranoid am I (traffic across the internet) -- Do you want the extra security / simplified routing / greater maintainence of using DTLS for your federated calling traffic? This gives you the benefit of being simpler to route across a network and enhanced security with certificate checking between backend calling components.


To begin with, we are going to assume you have calling working "properly". that means your users can use both wire calling services, and can find direct calling routes to the calling services. If this is not you, or if you are unsure, contact wire support to schedule a checkup of your calling services.

For this document, we are going to assume "not that paranoid" and "simplify networking, please."

### Coturn
external-ip annotation must be a PUBLIC IP address.

```yaml
coturnFederationListeningIP: '__COTURN_POD_IP__'
federate:
  enabled: true
  port: 9191
```

With dtls:
```yaml
coturnFederationListeningIP: '__COTURN_POD_IP__'
federate:
  enabled: true
  port: 9191
  dtls:
    enabled: true
    tls:
      issuerRef:
        name: letsencrypt-http01
      certificate:
        labels:
         # use-route53-dns-solver: "false" FIXME: chart wont deploy if certificate.labels is not in yaml
        dnsNames:
        - coturn.example.com
```

Redeploy `coturn`:

```bash
d helm upgrade --install coturn charts/coturn -f values/coturn/values.yaml -f values/coturn/secrets.yaml
```

### SFTD

#### TODO: charts/sftd/templates/statefulset.yaml for newer SFTD version

Need to be able to set -B parameter to POD_IP in exec sftd
current example:

```yaml
{{ if .Values.multiSFT.enabled}}-B "${POD_IP}" {{ end }} \
```

**FIXME:** (for older sftd)
external-ip annotation must be INTERNAL IP address

```yaml
allowOrigin: "https://webapp.example.com, https://webapp.example.org"
multiSFT:
  enabled: true
  discoveryRequired: false
  turnServerURI: "turn:federation.or.local.coturnIP:3478?transport=udp"
  secret: "turnSecretFromBrig"
```

Federated calls between SFT servers need to be enabled in the `brig` section of `wire-server/values.yaml` file.

```yaml
brig:
  config:
    multiSFT:
      enabled: true
```

Redeploy `sftd`
```bash
d helm upgrade --install sftd charts/sftd -f values/sftd/values.yaml
```

### Webapp

Domains of the federating backends will have to be added to the current list of webapp CSP headers for https and wss protocols.

```yaml
envVars:
  CSP_EXTRA_CONNECT_SRC: "https:*.example.org, wss://*.example.org"
```

Redeploy `webapp`:

```bash
d helm upgrade --install webapp charts/webapp -f values/webapp/values.yaml
```
