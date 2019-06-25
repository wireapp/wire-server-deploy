#!/usr/bin/env bash

docker run \
  -d \
  --network=host \
  --restart=always \
  --name registry \
  -v /mnt/registry:/var/lib/registry \
  -v "$(pwd)/certs:/certs" \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/client.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/client.key \
  registry:2
