This document describes the backup and restore process for RabbitMQ deployed outside of Kubernetes.

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
