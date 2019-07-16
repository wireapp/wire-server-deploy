## Interacting with elasticsearch

If you installed elasticsearch with the ansible playbook from this repo, you can interact with it like this (from an elasticsearch VM):

See cluster health

```
curl 'http://localhost:9200/_cat/nodes?v&h=id,ip,name'
```

For more information, see the [elasticsearch documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
