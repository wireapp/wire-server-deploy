# To Create a storage class for local persistent storage in Kubernetes

#### Note: This is just an example to create a local-path storage class. For the actual usecase, you can create your own storageclass with provisioner of your choice and use in different places to deploy wire-server and other resources.

Create a storage class.

You can find more information about the local persistent storage here: https://kubernetes.io/docs/concepts/storage/storage-classes/#local
Copy the following content in a file and name it sc.yaml

```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    name: local-path
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer

```

Create a Persistent Volume.

You can find more information about the Persistent Volume here: https://kubernetes.io/docs/concepts/storage/persistent-volumes/

Note: The below example will create a Persistent Volume on the node kubenode1. You can change the node name as per your requirement. And also make sure that the path /data/local-path exists on the node kubenode1.

Copy the following content in a file and name it pv.yaml

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-path-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
  -  ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  local:
    path: /data/local-path
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kubenode1
```

Create a Persistent Volume Claim.

You can find more information about the Persistent Volume Claim here: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims

Copy the following content in a file and name it pvc.yaml

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-pvc
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

Now, create the above resources using the following commands:

```
d kubectl apply -f sc.yaml
d kubectl apply -f pv.yaml
d kubectl apply -f pvc.yaml
```

After successfull creation, you should be able to see the resources with -
```
d kubectl get sc,pv,pvc
```
