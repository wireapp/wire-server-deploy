## DNS

Each Wire instance needs a SRV DNS record for federation to work (in addition to the ingress A record):

```
dig srv _wire-server-federator._tcp.example.com +short

0 10 443 federator.example.com.
```

## Ingress

SSL certs for the federator ingress can either be acquired via cert-manager and Letsencrypt if enabled in the [nginx-ingress-service/values.yaml](../values/nginx-ingress-services/prod-values.example.yaml)
or added manually, see "Bring your own certificates" in [offline/docs_ubuntu_22.04.md](./docs_ubuntu_22.04.md)


## Helm chart configuration

Our example [values.yaml](../values/wire-server/prod-values.example.yaml) and [secrets.yaml](../values/wire-server/prod-secrets.example.yaml) for `wire-server` are preconfigured to allow for enabling federation.
Look for any federation related settings and enable or adjust accordingly.
Important: `brig`, `galley` and `background-worker` need to be able to access RabbitMQ with the same secret.

Adding remote instances to federate with happens in the `brig` subsection in [values.yaml](../values/wire-server/prod-values.example.yaml):

```
     setFederationDomainConfigs:
       - domain: remotebackend1.example.com
         search_policy: full_search
```
Multiple domains with individual search policies can be added.

## RabbitMQ

You can refer to [offline/rabbitmq_setup.md](./rabbitmq_setup.md) for creating RabbitMQ cluster, if you haven't yet.
