# Administration

This section shows how to interact with some of the server components directly from within the respective virtual machine.

For any command below, first ssh into it:

```
ssh <name or IP of the VM>
```

## Restund (TURN)

### How to see how many people are currently connected to the restund server

Assuming you installed restund using the ansible playbook from this repo, you can interact with it like this (from a restund VM):

```sh
echo turnstats | nc -u 127.0.0.1 33000 -q1 | grep allocs_cur | cut -d' ' -f2
```

### How to restart restund

*Please note that restarting `restund` means any user that is currently connected to it (i.e. having a call) will lose its audio/video connection*

```
systemctl restart restund
```
