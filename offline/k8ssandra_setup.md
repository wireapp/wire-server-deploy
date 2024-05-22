# Setting up K8ssandra
Reference - https://docs.k8ssandra.io/install/local/single-cluster-helm/

K8ssandra will need following components to be installed in the cluster - 
- dynamic persistent volume provisioning(for e.g with Openebs)
- cert-manager
- minio(for backup and restore)
- K8ssandra-operator
- Configure minio bucket for backups

## [1] Dynamic Persistent Volume Provisioning
If you already have a dynamic persistent volume provisioning setup, you can skip this step. Else, we will be using Openebs for dynamic persistent volume provisioning.

Reference docs - https://openebs.io/docs/user-guides/local-storage-user-guide/local-pv-hostpath/hostpath-installation

Deploy Openebs -

```
d helm install openebs charts/openebs --namespace openebs --create-namespace
```
The above helm chart will be readily available in the offline artifact.

After successful deployment of openebs, you will see these storageclasses
```
d kubectl get sc
NAME               PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
openebs-device     openebs.io/local               Delete          WaitForFirstConsumer   false                  5d20h
openebs-hostpath   openebs.io/local               Delete          WaitForFirstConsumer   false                  5d20h
```

## [2] Install cert-manager
Note: For wire-in-a-box setup, cert-manager pods should not be running on same node as ingress-nginx-controller. Hence, we should first install the ingress-nginx-controller and than install cert-manager.

```
cp ./values/ingress-nginx-controller/prod-values.example.yaml ./values/ingress-nginx-controller/values.yaml
d helm install ingress-nginx-controller ./charts/ingress-nginx-controller --values ./values/ingress-nginx-controller/values.yaml
```
Now check where ingress-nginx-controller pod is running and install cert-manager on a different node.

```
d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```
For e.g. .. if it is `kubenode1`, taint the node
```
d kubectl cordon kubenode1
```
Now, download cert manager, and place it in the appropriate location:
```
wget https://charts.jetstack.io/charts/cert-manager-v1.13.2.tgz
tar -C ./charts -xvzf cert-manager-v1.13.2.tgz
```

Install `cert-manager` into a new namespace `cert-manager-ns`.
```
d kubectl create namespace cert-manager-ns
d helm upgrade --install -n cert-manager-ns --set 'installCRDs=true' cert-manager charts/cert-manager
```

Uncordon the node you cordonned earlier:
```
d kubectl uncordon kubenode1
```

## [3] Install Minio
Minio and minio-external chart should have been already installed, if you are following the docs_ubuntu_22.04.md

## [4] Deploy K8ssandra Operator
```
d helm install k8ssandra-operator charts/k8ssandra-operator -n database --create-namespace
```

## [5] Configure Minio Bucket for Backups
Create a secret to access Minio, make a new file `minio-secret.yaml`, and put into it -

Get the aws_access_key_id and aws_secret_access_key from ansible/inventory/offline/group_vars/all/secrets.yaml file, they will be under minio_access_key and minio_secret_key

```
apiVersion: v1
kind: Secret
metadata:
 name: medusa-bucket-key
 namespace: database
type: Opaque
stringData:
 credentials: |-
   [default]
   aws_access_key_id = UIWEGQZ53qVlLuQ2mkM3 #update this
   aws_secret_access_key = dpZqqiR0Bwz6Kc6J8ruPfTC1VqIPI4EM0Id6TLWG83 #update this
```

and apply this -

```d kubectl apply -f minio-secret.yaml```

Now, put this medusa config under spec section in ```charts/k8ssandra-test-cluster/templates/k8ssandra-cluster.yaml``` file -
```
medusa:
    storageProperties:
      storageProvider: s3_compatible
      region: eu-west-1
      bucketName: k8ssandra-backups
      host: minio-external
      port: 9000
      prefix: dc1
      storageSecretRef:
        name: medusa-bucket-key
      secure: false
      maxBackupAge: 7
```

## Install K8ssandra Test Cluster
In ```charts/k8ssandra-test-cluster/templates/k8ssandra-cluster.yaml``` update the following variables - 

Set `size` to 1

Set `storageClassName` to "openebs-hostpath"

Now, deploy it -

```
d helm upgrade --install k8ssandra-test-cluster charts/k8ssandra-test-cluster --namespace database
```

After successful deployment, change the size to 3 and than upgrade the deployment

Note: Deploying with size: 3 directly will result in some hostname resolution issues.
```
d helm upgrade --install k8ssandra-test-cluster charts/k8ssandra-test-cluster --namespace database
```

## Enable Backups
Reference - https://docs.k8ssandra.io/tasks/backup-restore/

To enable Medusa backup schedule and old backups purging schedule, create a file `k8ssandra-backup.yaml` -
```
apiVersion: medusa.k8ssandra.io/v1alpha1
kind: MedusaBackupSchedule
metadata:
  name: medusa-backup-schedule
  namespace: database
spec:
  backupSpec:
    backupType: differential
    cassandraDatacenter: datacenter-1
  cronSchedule: "30 1 * * *"
  disabled: false
  
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: k8ssandra-medusa-backup
  namespace: database
spec:
  schedule: "0 0 * * *"
  jobTemplate:
    spec:
      template:
        metadata:
          name: k8ssandra-medusa-backup
        spec:
          serviceAccountName: medusa-backup
          containers:
          - name: medusa-backup-cronjob
            image: bitnami/kubectl:1.29.3
            imagePullPolicy: IfNotPresent
            command:
             - 'bin/bash'
             - '-c'
             - 'printf "apiVersion: medusa.k8ssandra.io/v1alpha1\nkind: MedusaTask\nmetadata:\n  name: purge-backups-timestamp\n  namespace: database\nspec:\n  cassandraDatacenter: datacenter-1\n  operation: purge" | sed "s/timestamp/$(date +%Y%m%d%H%M%S)/g" | kubectl apply -f -'
          restartPolicy: OnFailure
```

Note: You can update the backup schedule as per your requirement, apply it with - 
```d kubectl apply -f k8ssandra-backup.yaml ```

You can see the backup schedular via -

```d kubectl get MedusaBackupSchedule -A```

and the past backups via - 

```d kubectl get MedusaBackupJob -A```

## Restoring a backup
Create a `restore-k8ssandra.yaml` file and put into it below content and replace the backup name from the one you want to restore with, you can get the name from `d kubectl get MedusaBackupJob -A`

```
apiVersion: medusa.k8ssandra.io/v1alpha1
kind: MedusaRestoreJob
metadata:
  name: restore-backup1
  namespace: database
spec:
  cassandraDatacenter: dc1
  backup: medusa-backup1
```

and apply it

```d kubectl apply -f restore-k8ssandra.yaml```
