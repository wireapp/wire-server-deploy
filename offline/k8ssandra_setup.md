# Setting up K8ssandra
Reference - https://docs.k8ssandra.io/install/local/single-cluster-helm/

K8ssandra will need the following components to be installed in the cluster - 
- Dynamic persistent volume provisioning (e.g with OpenEBS)
- Cert-Manager
- Minio (for backup and restore)
- K8ssandra-operator
- Configure minio bucket for backups

## [1] Dynamic Persistent Volume Provisioning
Refer to [offline/local_persistent_storage_k8s](./local_persistent_storage_k8s.md)

## [2] Install cert-manager
cert-manager is a must requirement for k8ssandra - see https://docs.k8ssandra.io/install/local/single-cluster-helm/#deploy-cert-manager for why.

To install the cert-manager, follow the steps mentioned in `Use letsencrypt generated certificates` section in [offline/docs_ubuntu_22.04.md](./docs_ubuntu_22.04.md)

## [3] Install Minio
Minio and minio-external chart should have been already installed, if you are following docs_ubuntu_22.04.md

## [4] Deploy K8ssandra Operator
```
cp ./values/k8ssandra-operator/prod-values.example.yaml ./values/k8ssandra-operator/values.yaml

d helm install k8ssandra-operator charts/k8ssandra-operator --values ./values/k8ssandra-operator/values.yaml -n database --create-namespace
```

## [5] Configure Minio Bucket for Backups
Create a K8s secret for k8ssandra to access with Minio by applying `minio-secret.yaml` below.

You can find the value of `aws_access_key_id` and `aws_secret_access_key` from `ansible/inventory/offline/group_vars/all/secrets.yaml` file, they will be named `minio_access_key` and `minio_secret_key` respectively. Replace them in the secret config below.

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

Apply the secret:

```d kubectl apply -f minio-secret.yaml```

Now, put this medusa config directly below the `spec:` section in `charts/k8ssandra-test-cluster/templates/k8ssandra-cluster.yaml`:
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
Create a copy of the provided values file -
```
cp ./values/k8ssandra-test-cluster/prod-values.example.yaml ./values/k8ssandra-test-cluster/values.yaml
```

You can update the values in the `values/k8ssandra-test-cluster/values.yaml` file as per your requirement.

Now, deploy it -

```
d helm upgrade --install k8ssandra-test-cluster charts/k8ssandra-test-cluster --values values/k8ssandra-test-cluster/values.yaml --namespace database
```

After successful deployment, change the `datacenter -> size` to 3 in ```values/k8ssandra-test-cluster/values.yaml``` and upgrade the deployment.

Note: Deploying with size: 3 directly will result in some hostname resolution issues.
```
d helm upgrade --install k8ssandra-test-cluster charts/k8ssandra-test-cluster --values values/k8ssandra-test-cluster/values.yaml --namespace database
```

## Enable Backups
Reference - https://docs.k8ssandra.io/tasks/backup-restore/

To enable Medusa backup schedule and purging schedule for old backups, create a file `k8ssandra-backup.yaml`:
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
