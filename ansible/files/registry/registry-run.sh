#!/usr/bin/env bash

IP=${1:-"0.0.0.0"}
PORT=${2:-"5001"}

docker run \
  -d \
  --network=host \
  --restart=always \
  --name registry \
  -v $(pwd)/../../mnt/registry:/var/lib/registry \
  -v "$(pwd)/certs:/certs" \
  -e REGISTRY_HTTP_ADDR=${IP}:${PORT} \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/client.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/client.key \
  registry:2
