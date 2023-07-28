# Migrating your Ubuntu 18 based deployment to Ubuntu 22.
On your current Ubuntu 18 based deployment you might be using the following version of required tools:
<br>Kubernetes - 1.19.7<br>
Ansible - 2.9.6
<br><br>
while on the new Ubuntu 22 based deployment you will be using the following version of required tools:
<br>Kubernetes - 1.23.7<br>
Ansible - 2.11.6
<br><br>
### We will be deploying the new environment in parallel to the old one and then migrate the data from the old one to the new one. At the end we will remove the old environment.
<br>

## On your current Ubuntu 18 based deployment -
### Backup your wire-server-deploy directory.
```
tar -cvf wire-server-deploy-old.tar <path_to_wire_server>
```


### Backup your cassandra data directory from each ansible nodes.

Stop Cassandra on all ansnodes (ansnode1, 2, 3) using the command: 
```
sudo service cassandra stop
```
Verify that it's stopped with:
```
sudo service cassandra status
```
For each ansnode, create a backup of the /mnt/cassandra folder using the tar command.
For example, on ansnode1, run: 
```
tar -cvf ~/mnt-cassandra-1.tar /mnt/cassandra
```
Verify the tar files by listing them with:
```
ls -lh ~/mnt*.tar.
```

Repeat the above steps for each ansnode, replacing the number in the file name with the respective ansnode number.

If needed, restart Cassandra on each ansnode using:
```
sudo service cassandra start
```

Copy the tar files from the origin machine to your local machine using the scp command:
```
scp demo@origin-machine:~/mnt*.tar /tmp/.
```

Transfer the tar files from your local machine to the destination machine using: 
```
scp '/tmp/mnt*.tar' demo@destination-machine:~/.
```

You can also directly move the tar files from the origin machine to the destination machine.<br><br>


### Backup your Minio data directory from each ansible nodes.
On each ansnode, create a backup of the /var/lib/minio-server1 and /var/lib/minio-server2 folders using the tar command. For example, on ansnode1, run:
```
sudo tar -cvf minio-server1-ansnode1.tar /var/lib/minio-server1
sudo tar -cvf minio-server2-ansnode1.tar /var/lib/minio-server2
```

Repeat the steps for the other ansnodes, replacing the number in the file name with the respective ansnode number.

At the end, you should have 6 tar files, 2 for each ansnode.
Get them all in a single folder on the host machine, and compress them into a single tar file:
```
tar -cvf minio-backup.tar minio-server1-ansnode1.tar minio-server2-ansnode1.tar minio-server1-ansnode2.tar minio-server2-ansnode2.tar minio-server1-ansnode3.tar minio-server2-ansnode3.tar
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

Now, we will create a kubernets cluster on the new machine.
First cd into the wire-server-deploy directory.
```
cd wire-server-deploy
```
Now, follow the instruction from here upto step `Ensuring kubernetes is healthy` - https://github.com/wireapp/wire-server-deploy/blob/update_to_ubuntu_22/offline/docs_ubuntu_22.04.md#making-tooling-available-in-your-environment

Now, you will be having a kubernetes v1.23.7 cluster up and running on your new machine.

We will need to restore the minio data files on the new machine first before procedding further.<br>
You should have minio-backup.tar file on your new machine. Untar it in a new directory.
```
mkdir minio-backup
cd minio-backup
tar -cvf ../minio-backup.tar
cd .. # Go back to the parent directory
```
Now, we will restore the minio data files on the specific ansnodes.
Move the respective backup files to the respective ansnodes using scp.
```
scp minio-backup/minio-server1-ansnode1.tar demo@ansnode1:
scp minio-backup/minio-server2-ansnode1.tar demo@ansnode1:
```
Repeat the above steps for the other ansnodes, replacing the number in the file name with the respective ansnode number.

Now ssh into each ansnode and restore the minio data files.
```
ssh demo@ansnode1
cd /
tar -cvf /home/demo/minio-server1-ansnode1.tar
tar -cvf /home/demo/minio-server2-ansnode1.tar
```
Repeat the above steps for the other ansnodes, replacing the number in the file name with the respective ansnode number.

Now, continue with the next steps of the wire installation from here, till end - https://github.com/wireapp/wire-server-deploy/blob/update_to_ubuntu_22/offline/docs_ubuntu_22.04.md#non-kubernetes-services-restund-cassandra-elasticsearch-minio

As of now, you should have a new wire-server deployment up and running on your new Ubuntu 22 based host machine.
Do not try to login/sign-up yet.<br>
We will now restore the cassandra data files on the new machine.<br>
Stop Cassandra on each ansnode using: ```sudo service cassandra stop```<br>
Now on each node,
- Copy each tar file to the respective ansnode using scp. For example, for ansnode1:
```scp mnt-cassandra-1.tar ansnode1:~/. ```
- SSH into each ansnode1
- Create a working folder on each ansnode: ```mkdir ~/mnt-cassandra-1/.```
- Navigate to the working folder: ```cd ~/mnt-cassandra-1/.```
- Extract the tar file: ```tar -cvf ../mnt-cassandra-1.tar```
- Back up the original Cassandra folder: ```sudo mv /mnt/cassandra /mnt/orig-cassandra/.```
- Copy the extracted files to the destination: ```sudo cp -rvf ~/mnt-cassandra-1/mnt/cassandra /mnt/.```
- Set the correct ownership for the files: ```sudo chown -R cassandra:cassandra /mnt/cassandra/.```
- Start Cassandra on each ansnode: ```sudo service cassandra start```
- Verify with: ```sudo service cassandra status```
- Check the status of the nodes using: sudo nodetool status.
- Connect to the Cassandra instance using cqlsh: sudo docker run -it --rm cassandra:3.11 cqlsh 172.16.0.132 9042.
- Switch to the desired keyspace using: use brig;.
- Retrieve the user data with: select * from user;.
- The output should display the user data from the origin machine.

Now, you can try to login/sign-up on the new wire-server deployment on your new Ubuntu 22 based host machine.<br>
You should be able to see the old chat history and download the old attachments.
