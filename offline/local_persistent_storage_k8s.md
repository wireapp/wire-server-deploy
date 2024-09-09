## Dynamic Persistent Volume Provisioning
If you already have a dynamic persistent volume provisioning setup, you can skip this step. If not, we can use OpenEBS for dynamic persistent volume provisioning.

Reference docs - https://openebs.io/docs/user-guides/local-storage-user-guide/local-pv-hostpath/hostpath-installation

### Deploy OpenEBS

```
d helm install openebs charts/openebs --namespace openebs --create-namespace
```
The above helm chart is available in the offline artifact.

After successful deployment of OpenEBS, you will see these storage classes:
```
d kubectl get sc
NAME               PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
openebs-device     openebs.io/local               Delete          WaitForFirstConsumer   false                  5d20h
openebs-hostpath   openebs.io/local               Delete          WaitForFirstConsumer   false                  5d20h
```

### Backup and Restore

For backup and restore of the OpenEBS Local Storage, refer to the official docs at - https://openebs.io/docs/user-guides/local-storage-user-guide/additional-information/backupandrestore
