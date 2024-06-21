This document describes the backup and restore process for RabbitMQ deployed outside of Kubernetes.

## Backup
Make sure to have the nodes on which RabbitMQ is running in the [ansible inventory file](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#editing-the-inventory), under the `rmq-cluster` group.
Then run the following command:
```
source bin/offline-env.sh
```

Replace `/path/to/backup` in the command below with the backup target path on the rabbitmq nodes.

```
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/rabbitmq_backup.yml --extra-vars "backup_dir=/path/to/backup"
```

This ansible playbook will create `definitions.json` (Definitions) and `rabbitmq-backup.tgz` (Messages) files on all RabbitMQ nodes at `/path/to/backup`.

Now, save these files on your host machine with scp command -
```
mkdir rabbitmq_backups
cd rabbitmq_backups
```
Fetch the backup files for each node one by one,
```
scp -r <node_name>:<path_to_store_backup>/ <node_name>/
```


## Restore
To restore the RabbitMQ backup,
Copy the backup files to the specific nodes at `<path_to_store_backup>` for each node -
```
scp -r <node_name>/ <node_name>:<path_to_store_backup>/
```

Than ssh into each node and run the following command from the path `<path_to_store_backup>` -
To restore the definitions - 
```
rabbitmqadmin import definitions.json
```
To restore the data -
```
sudo tar xvf rabbitmq-backup.tgz -C /
sudo chown -R rabbitmq:rabbitmq /var/lib/rabbitmq/mnesia # To ensure the correct permissions
```
