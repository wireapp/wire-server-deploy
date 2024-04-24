Create minio secret object


Get the minio secrets from `ansible/inventory/offline/group_vars/all/secrets.yaml` file, and put them below.
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
   aws_access_key_id = minio_key
   aws_secret_access_key = minio_secret  
```

Medusa config in k8ssandra-test-cluster
```
medusa:
    storageProperties:
      storageProvider: "s3_compatible"
      region: "eu-west-1"
      bucketName: "dummy-bucket"
      host: minio-external.local
      port: 9000
      prefix: "dc1"
      storageSecretRef:
        name: "medusa-bucket-key"
      secure: true
      maxBackupAge: 7
```

apiVersion: medusa.k8ssandra.io/v1alpha1
kind: MedusaBackupJob
metadata:
  name: medusa-backup1
  namespace: database
spec:
  cassandraDatacenter: datacenter-1
