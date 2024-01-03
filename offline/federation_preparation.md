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

**Important:** RabbitMQ nodes address each other using a node name, for e.g rabbitmq@ansnode1
Please refer to the official documentation and configure your DNS based on the setup - https://www.rabbitmq.com/clustering.html#cluster-formation-requirements


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
