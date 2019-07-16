## Interacting with restund

If you installed restund with the ansible playbook from this repo, you can interact with it like this (from a restund VM):

```sh
# see current allocations
echo turnstats | nc -u 127.0.0.1 33000 -q1 | grep allocs_cur | cut -d' ' -f2
```

