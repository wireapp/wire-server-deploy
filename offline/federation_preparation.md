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

There are two methods to deploy the RabbitMQ cluster:

### Method 1: Install RabbitMQ inside kubernetes cluster with the help of helm chart

To install the RabbitMQ service, first copy the value and secret files:
```
cp ./values/rabbitmq/prod-values.example.yaml ./values/rabbitmq/values.yaml
cp ./values/rabbitmq/prod-secrets.example.yaml ./values/rabbitmq/secrets.yaml
```
By default this will create a RabbitMQ deployment with ephemeral storage. To use the local persistence storage of Kubernetes nodes, please refer to the related documentation in [offline/local_persistent_storage_k8s.md](./local_persistent_storage_k8s.md).

Now, update the `./values/rabbitmq/values.yaml` and `./values/rabbitmq/secrets.yaml` with correct values as needed.

Deploy the `rabbitmq` helm chart:
```
d helm upgrade --install rabbitmq ./charts/rabbitmq --values ./values/rabbitmq/values.yaml --values ./values/rabbitmq/secrets.yaml
```

### Method 2: Install RabbitMQ outside of the Kubernetes cluster with an Ansible playbook

Add the nodes on which you want to run rabbitmq to the `[rmq-cluster]` group in the `ansible/inventory/offline/hosts.ini` file. Also, update the `ansible/roles/rabbitmq-cluster/defaults/main.yml` file with the correct configurations for your environment.

If you need RabbitMQ to listen on a different interface than the default gateway, set `rabbitmq_network_interface`

You should have following entries in the `/ansible/inventory/offline/hosts.ini` file. For example:
```
[rmq-cluster:vars]
rabbitmq_network_interface = enp1s0

[rmq-cluster]
ansnode1
ansnode2
ansnode3
```


#### Hostname Resolution
RabbitMQ nodes address each other using a node name, a combination of a prefix and domain name, either short or fully-qualified (FQDNs). For e.g. rabbitmq@ansnode1

Therefore every cluster member must be able to resolve hostnames of every other cluster member, its own hostname, as well as machines on which command line tools such as rabbitmqctl might be used.

Nodes will perform hostname resolution early on node boot. In container-based environments it is important that hostname resolution is ready before the container is started.

Hostname resolution can use any of the standard OS-provided methods:

For e.g. DNS records
Local host files (e.g. /etc/hosts)
Reference - https://www.rabbitmq.com/clustering.html#cluster-formation-requirements


For adding entries to local host file(`/etc/hosts`), run
```
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/roles/rabbitmq-cluster/tasks/configure_dns.yml
```

Create the rabbitmq cluster:

``` 
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/rabbitmq.yml
```

and run the following playbook to create values file for helm charts to look for RabbitMQ IP addresses -

```
d ansible-playbook -i ./ansible/inventory/offline/hosts.ini ansible/helm_external.yml --tags=rabbitmq-external
```

Make Kubernetes aware of where RabbitMQ external stateful service is running:
```
d helm install rabbitmq-external ./charts/rabbitmq-external --values ./values/rabbitmq-external/values.yaml
```

Configure wire-server to use the external RabbitMQ service:

Edit the `/values/wire-server/prod-values.example.yaml` file to update the RabbitMQ host
Under `brig` and `galley` section, you will find the `rabbitmq` config, update the host to `rabbitmq-external`, it should look like this:
```
rabbitmq:
  host: rabbitmq-external
``` 
