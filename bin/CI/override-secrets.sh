#!/usr/bin/env bash

set -e

sudo docker run --rm quay.io/wire/zauth -m gen-keypair -i 1 > keys.txt

cp values/wire-server/demo-values.example.yaml values/wire-server/demo-values.yaml
cp values/wire-server/demo-secrets.example.yaml values/wire-server/demo-secrets.yaml

TURN=$(openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42)
PUBLIC=$(sed -n 's/public: \(.*\)/\1/p' keys.txt)
PRIVATE=$(sed -n 's/secret: \(.*\)/\1/p' keys.txt)

yq w -i values/wire-server/demo-secrets.yaml brig.secrets.turn.secret "$TURN"
yq w -i values/wire-server/demo-secrets.yaml brig.secrets.zAuth.privateKeys "$PRIVATE"
yq w -i values/wire-server/demo-secrets.yaml brig.secrets.zAuth.publicKeys "$PUBLIC"
yq w -i values/wire-server/demo-secrets.yaml nginz.secrets.zAuth.publicKeys "$PUBLIC"
