#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VALUES_DIR="$( cd "$SCRIPT_DIR/../values" && pwd )"

init="${VALUES_DIR}/values-init-done"

if [[ -f $init ]]; then
    echo "initialization already done. Not overriding. Exiting."
    exit 1
fi

cp -v $VALUES_DIR/wire-server/{prod-values.example,values}.yaml
cp -v $VALUES_DIR/wire-server/{prod-secrets.example,secrets}.yaml
cp -v $VALUES_DIR/databases-ephemeral/{prod-values.example,values}.yaml
cp -v $VALUES_DIR/fake-aws/{prod-values.example,values}.yaml
cp -v $VALUES_DIR/ingress-nginx-controller/{prod-values.example,values}.yaml
cp -v $VALUES_DIR/nginx-ingress-services/{prod-values.example,values}.yaml
cp -v $VALUES_DIR/nginx-ingress-services/{prod-secrets.example,secrets}.yaml
cp -v $VALUES_DIR/demo-smtp/{prod-values.example,values}.yaml

#cp "$VALUES_DIR/cassandra-external/{prod-values.example,values}.yaml"
#cp "$VALUES_DIR/minio-external/{prod-values.example,values}.yaml"
#cp "$VALUES_DIR/elasticsearch-external/{prod-values.example,values}.yaml"

echo "done" > "$init"
