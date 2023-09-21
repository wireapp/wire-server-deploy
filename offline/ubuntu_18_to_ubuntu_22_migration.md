# Migrating your Ubuntu 18 based deployment to Ubuntu 22.

NOTE: The following migration process was done as a clean install of wire-server on new Ubuntu 22.04 VMs, then restoring a backed up snapshot of Cassandra and MiniO.

**IMPORTANT**: You should notify your users of the planned migration and stop all wire-server services before making any backup snapshots and keep it down until upgrade is complete! For extra security, have your users backup their conversation history!
On your current Ubuntu 18 based deployment you might be using the following version of required tools:
<br>Kubernetes - 1.19.7<br>
Ansible - 2.9.6
<br><br>
While on the new Ubuntu 22 based deployment you will be using the following version of required tools:
<br>Kubernetes - 1.23.7<br>
Ansible - 2.11.6
<br><br>

### We will be deploying the new environment in parallel to the old one and then migrate the data from the old one to the new one. At the end we will remove the old environment.

<br>
## On your current Ubuntu 18 based deployment -

### Uninstall wire-server deployment

`d helm uninstall wire-server`

### Backup your wire-server-deploy directory.

This is where all your configurations/secrets are which will be needed for a successful upgrade.

```
tar -cvf wire-server-deploy-old.tar <path_to_wire_server>
```

### Backup your cassandra data directory from each node.

Stop Cassandra on all node using the command:

```
sudo service cassandra stop
```

Verify that it's stopped with:

```
sudo service cassandra status
```

For each node, create a backup of the /mnt/cassandra folder using the tar command.
For example, run:

```
tar -cvf ~/mnt-cassandra-1.tar /mnt/cassandra
```

Verify the tar files by listing them with:

```
ls -lh ~/mnt*.tar.
```

Repeat the above steps for each node, replacing the number in the file name with the respective node number.

Copy the tar files from the origin machine to your local machine using the scp command:

```
scp demo@origin-machine:~/mnt*.tar /tmp/.
```

Transfer the tar files from your local machine to the destination machine using:

```
scp '/tmp/mnt*.tar' demo@destination-machine:~/.
```

You can also directly move the tar files from the origin machine to the destination machine.<br><br>

### Backup your Minio data directory from each node.

On each node, create a backup of the /var/lib/minio-server1 and /var/lib/minio-server2 folders using the tar command. For example, run:

```
sudo tar -cvf minio-server1-node1.tar /var/lib/minio-server1
sudo tar -cvf minio-server2-node1.tar /var/lib/minio-server2
```

Repeat the steps for the other nodes, replacing the number in the file name with the respective node number.

At the end, you should have 6 tar files, 2 for each node.
Get them all in a single folder on the host machine, and compress them into a single tar file:

```
tar -cvf minio-backup.tar minio-server1-node1.tar minio-server2-node1.tar minio-server1-node2.tar minio-server2-node2.tar minio-server1-node3.tar minio-server2-node3.tar
```

Copy the minio-backup tar file to the destination machine with ubuntu 22 using scp:

```
scp minio-backup.tar demo@destination-machine:~/.
```

## On your new Ubuntu 22 based host machine -

As of now, you should have the following files on your new Ubuntu 22 based host machine:

- Docker installed on your host machine.(Follow these instructions to install docker - https://github.com/wireapp/wire-server-deploy/blob/update_to_ubuntu_22/offline/docs_ubuntu_22.04.md#installing-docker)
- Tar file of backed up wire-server-deploy-old directory.
- Tar file of backed up cassandra data directory.
- Tar file of backed up minio data directory.

Get the new offline artifact from Wire which has all the required binaries and dependencies for new version of Ubuntu, Kubernetes and Ansible.

```
wget <link_to_the_artifact>
```

Untar the above artifact in a new directory.

```
mkdir wire-server-deploy
cd wire-server-deploy
tar -xvzf ../<name_of_artifact.tar.gz>
cd .. # Go back to the parent directory
```

Now untar the wire-server-deploy-old.tar file in another directory.

```
mkdir wire-server-deploy-old
cd wire-server-deploy-old
tar -xvf wire-server-deploy-old.tar
cd .. # Go back to the parent directory
```

Copy the `values/wire-server/secrets.yaml` and `ansible/inventory/offline/group_vars/all/secrets.yaml` from the old wire-server-deploy to the new one.

```
cp wire-server-deploy-old/values/wire-server/secrets.yaml wire-server-deploy/values/wire-server/secrets.yaml
cp wire-server-deploy-old/ansible/inventory/offline/group_vars/all/secrets.yaml wire-server-deploy/ansible/inventory/offline/group_vars/all/secrets.yaml
```

**IMPORTANT**: Skip the configuration parts and generating secrets part as we have those from your previous deployment. Compare the “old” files with the new ones in case of changes between your old deployment and this one.

Now, we will create a kubernets cluster on the new machine.
First cd into the wire-server-deploy directory.

```
cd wire-server-deploy
```

Now, follow the instruction from here up to step `Ensuring kubernetes is healthy` - https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#ensuring-kubernetes-is-healthy

Now, you will be having a kubernetes v1.23.7 cluster up and running on your new machine.

We will need to restore the minio data files on the new machine first before procedding further.<br>
You should have minio-backup.tar file on your new machine. Untar it in a new directory.

```
mkdir minio-backup
cd minio-backup
tar -xvf ../minio-backup.tar
cd .. # Go back to the parent directory
```

Now, we will restore the minio data files on the specific nodes.
Move the respective backup files to the respective nodes using scp.

```
scp minio-backup/minio-server1-node1.tar demo@node1:
scp minio-backup/minio-server2-node1.tar demo@node1:
```

Repeat the above steps for the other nodes, replacing the number in the file name with the respective node number.

Now ssh into each node and restore the minio data files.

```
ssh demo@node1
cd /
tar -xvf /home/demo/minio-server1-node1.tar
tar -xvf /home/demo/minio-server2-node1.tar
```

Repeat the above steps for the other nodes, replacing the number in the file name with the respective node number.

Now run the minio playbook.

**IMPORTANT**: Do not proceed with wire-server installation until you have restored backed up minio-server files!

Now, continue with the next steps of the wire installation from here and install the rest of ansible playbooks (including cassandra!).

After running cassandra playbook start the restore process:

- Copy each tar file to the respective node using scp. For example, for node1:
  `scp mnt-cassandra-1.tar node1:~/. `
- SSH into each node1
- Create a working folder on each node: `mkdir ~/mnt-cassandra-1/.`
- Navigate to the working folder: `cd ~/mnt-cassandra-1/.`
- Extract the tar file: `tar -cvf ../mnt-cassandra-1.tar`
- Copy the extracted files to the destination: `sudo cp -rvf ~/mnt-cassandra-1/mnt/cassandra /mnt/.`
- Set the correct ownership for the files: `sudo chown -R cassandra:cassandra /mnt/cassandra/.`
- Start Cassandra on each node: `sudo service cassandra start`
- Verify with: `sudo service cassandra status`
- Check the status of the nodes using: sudo nodetool status.
- Connect to the Cassandra instance using cqlsh: sudo docker run -it --rm cassandra:3.11 cqlsh internal.ip.addr 9042.
- Switch to the desired keyspace using: use brig;.
- Retrieve the user data with: select \* from user;.
- The output should display the user data from the origin machine.

Continue with the rest of wire-server deployment as usual untill done.

Now, you can try to login/sign-up on the new wire-server deployment on your new Ubuntu 22 based host machine.<br>
You should be able to see the old chat history and download the old attachments.
