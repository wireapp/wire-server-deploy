## Interacting with cassandra

If you installed cassandra with the ansible playbook from this repo, you can interact with it like this (from a cassandra VM):

See cluster health

```
nodetool status
```

Inspect tables

```
cqlsh
# from the cqlsh shell
describe keyspaces
use <keyspace>;
describe tables;
```

For more information, see the [cassandra documentation](https://cassandra.apache.org/doc/latest/)
