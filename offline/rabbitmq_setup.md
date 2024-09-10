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


## Backup and Restore

Following steps describe the backup and restore process for RabbitMQ deployed outside of Kubernetes.

Although, this can vary based on your setup, it is also recommended to follow the official documentation here - https://www.rabbitmq.com/docs/backup

## Backup
Make sure to have the nodes on which RabbitMQ is running in the [ansible inventory file](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#editing-the-inventory), under the `rmq-cluster` group.
Then run the following command:
```
source bin/offline-env.sh
```

Replace `/path/to/backup` in the command below with the backup target path on the rabbitmq nodes.

```
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/backup_rabbitmq.yml --extra-vars "backup_dir=/path/to/backup"
```

This ansible playbook will create `definitions.json` (Definitions) and `rabbitmq-backup.tgz` (Messages) files on all RabbitMQ nodes at `/path/to/backup`.

Now, save these files on your host machine with scp command -
```
mkdir rabbitmq_backups
cd rabbitmq_backups
```
Fetch the backup files for each node one by one,
```
scp -r <node_name>:/path/to/backup/ <node_name>/
```


## Restore
You should have the definition and data backup files on your host machine for each node, in the specific `node_name` directory.
To restore the RabbitMQ backup,
Copy both files to the specific nodes at `/path/to/restore/from` for each node -
```
scp -r <node_name>/ <node_name>:/path/to/restore/from
```

### Restore Definitions
ssh into each node and run the following command from the path `/path/to/restore/from` -
```
rabbitmqadmin import definitions.json
```

### Restore Data
To restore the data, we need to stop the rabbitmq service on each node first -
On each nodes, stop the service with -
```
ssh <node_name>
sudo systemctl stop rabbitmq-server
```

Once the service is stopped, restore the data -

```
sudo tar xvf rabbitmq-backup.tgz -C /
sudo chown -R rabbitmq:rabbitmq /var/lib/rabbitmq/mnesia # To ensure the correct permissions
```

At the end, restart the RabbitMQ server on each node -
```
sudo systemctl start rabbitmq-server
```

At the end, please make sure that the RabbitMQ is running fine on all the nodes.
