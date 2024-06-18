This document is for ansible based RabbitMQ outside of Kubernetes.

## Backup
To take a backup of RabbitMQ,

Make sure you have the nodes on which RabbitMQ is running in the inventory file, under `rmq-cluster` group.
Than run the following command,
```
source bin/offline-env.sh
```

Replace the `<path_to_store_backup>` in the below command with the path where you want to store the backup in the rabbitmq nodes.

```
d ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/rabbitmq_backup.yml --extra-vars "backup_dir=<path_to_store_backup>"
```

This ansible playbook will create `<node_name>_definitions.json` and `<node_name>_rabbitmq-backup.tgz` in all the RabbitMQ nodes.
For e.g, ansnode1 will have `ansnode1_definitions.json` and `ansnode1_rabbitmq-backup.tgz` file created in the path `<path_to_store_backup>`.
These files are the backup of the RabbitMQ definitions and messages respectively.

