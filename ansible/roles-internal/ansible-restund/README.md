## ansible-restund

## Requirements

- ansible >= 2.4
- ensure you have generated a secret before as described [here](https://github.com/wireapp/wire-server-deploy/blob/master/charts/brig/values.yaml#L66-L71)

## Preparation

Before provisioning, ensure you replace the `restund_zrest_secret` as described in the sample restund.yml playbook.

## How do I connect this restund server with wire-server?

Once you have a provisioned server, take note of the advertised IP address and ports (for UDP and TCP) and then add them in your wire-server installation. I.e., if your server is now running at `a.b.c.d` and the used udp/tcp port is 3478, then add that config as examplified [here](https://github.com/wireapp/wire-server-deploy/blob/master/charts/brig/values.yaml#L66-L71).

**Status: beta**, see [TODO](TODO.md)
