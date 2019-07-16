# Ansible

TODO

## Troubleshooting

`ansible all -i inventory.ini -m shell -a "echo hello"`

If your target machine only has python 3 (not python 2.7), avoid bootstrapping python 2.7 by:

```
# inventory.ini

[all]
server1 ansible_host=1.2.3.4

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

(python 3 may not be supported by all ansible modules yet)
