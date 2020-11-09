# TODO: turn this into some docs. These aren't meant to be fire-and-forget, as things might need to stabilize in between.

```
helm upgrade --install cassandra-external ./static/charts/cassandra-external --values ./values/cassandra-external/values.yml
helm upgrade --install elasticsearch-external ./static/charts/cassandra-external --values ./values/cassandra-external/values.yml
helm upgrade --install minio-external wire/minio-external -f values/minio-external/values.yam

# Install redis; the only ephemeral database
helm upgrade --install redis-ephemeral ./static/charts/redis-ephemeral

# Install reaper; to make sure cannons get restarted whenever redis restarts
helm upgrade --install reaper ./static/charts/reaper

# Install fake-aws (without the S3 bits)
helm upgrade --install fake-aws ./static/charts/fake-aws -f ./values/fake-aws/values.yaml

# Install demo-smtp
helm upgrade --install demo-smtp ./static/charts/demo-smtp -f ./values/demo-smtp/prod-values.example.yaml

# Hand-Craft values/wire-server/secrets.yaml, then deploy the wire-server chart
# Should make sure this secrets.yaml contains the restund auth token; as configured in the restund playbook

helm upgrade --install wire-server ./static/charts/wire-server -f ./values/wire-server/prod-values.example.yaml -f ./values/wire-server/secrets.yaml
```
