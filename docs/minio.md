## Interacting with minio

If you installed minio with the ansible playbook from this repo, you can interact with it like this:


```
# from a minio machine

mc config host add server1 http://localhost:9091 <access_key> <access_secret>

mc admin info server1
```

For more information, see the [minio documentation](https://docs.min.io/)
