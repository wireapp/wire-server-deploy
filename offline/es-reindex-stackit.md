# How to reindex Elasticsearch

Charts required: wget https://s3-eu-west-1.amazonaws.com/public.wire.com/charts-develop/elasticsearch-migrate-0.1.0.tgz

These charts configure Kubernetes jobs that run once. In case of any issues and attempts to rerun them, you will get an error. To clear this, delete the previously ran job in K8s.

## Configure new index

```
reindexType: "reindex"
runReindex: false
elasticsearch:
  host: # your elasticsearch host here
  index: directory_new
cassandra:
  host: # your cassandra host here
image:
  tag: 5.23.0 # or 5.25.0 if running wire-server-5.25.0
```

Apply the charts.

## Configure brig to use new index

```
brig:
  config:
    elasticsearch:
      host: elasticsearch-external
      index: directory
      additionalWriteIndex: directory_new
```

Apply

## Configure reindexing of the new index

```
reindexType: "reindex"
runReindex: true # set to true!
elasticsearch:
  host: # your elasticsearch host here
  index: directory_new
cassandra:
  host: # your cassandra host here
image:
  tag: 5.23.0
```

Apply
Process might take several hours, depending on the amount of data.

Troubleshooting:
- `galley` OOMKilled - increase memory for requests and limits (we found 8Gi to be enough in our prod):

```
galley:
  resources:
    requests:
      memory: 8Gi
    limits:
      memory: 8Gi
```
- anything else - reach out to Wire Support

Restart reindexing job after any issues

## Configure wire-server to use new index

```
brig:
  config:
    elasticsearch:
      index: directory_new
elasticsearch-index:
  elasticsearch:
    index: directory_new
```

Apply.

Verify everything is alright on the client side (Team Settings).

## Elasticsearch useful requests

- List indices - `curl "localhost:9200/_cat/indices?v"`
- Delete index - `curl -X DELETE "localhost:9200/index-name"`