This document describes the backup and restore process for RabbitMQ deployed outside of Kubernetes.

## Backup
To take a backup of RabbitMQ,

Make sure you have the nodes on which RabbitMQ is running in the inventory file, under the `rmq-cluster` group.
Then run the following command,
```
source bin/offline-env.sh
```

Replace `<path_to_store_backup>` in the below command with the path where you want to store the backup on the rabbitmq nodes.

```
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/rabbitmq_backup.yml --extra-vars "backup_dir=<path_to_store_backup>"
```

This ansible playbook will create `definitions.json` and `rabbitmq-backup.tgz` on all the RabbitMQ nodes at `<path_to_store_backup>`.
These files are the backup of the RabbitMQ definitions and messages respectively.

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
