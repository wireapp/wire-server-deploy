#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ANSIBLE_DIR="$( cd "$SCRIPT_DIR/../ansible" && pwd )"
VALUES_DIR="$(cd "$SCRIPT_DIR/../values" && pwd)"

ZAUTH_CONTAINER="${ZAUTH_CONTAINER:-quay.io/wire/zauth:latest}"

zrest="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 64)"

minio_access_key="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)"
minio_secret_key="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 42)"

minio_cargohold_access_key="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)"
minio_cargohold_secret_key="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 30)"

zauth="$(sudo docker run $ZAUTH_CONTAINER -m gen-keypair -i 1)"

zauth_public=$(echo "$zauth" | awk 'NR==1{ print $2}')
zauth_private=$(echo "$zauth" | awk 'NR==2{ print $2}')

prometheus_pass="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)"

echo "Writing $VALUES_DIR/wire-server/prod-secrets.example.yaml"
cat <<EOF > $VALUES_DIR/wire-server/prod-secrets.example.yaml
brig:
  secrets:
    smtpPassword: dummyPassword
    zAuth:
      publicKeys: "$zauth_public"
      privateKeys: "$zauth_private"
    turn:
      secret: "$zrest"
    awsKeyId: dummykey
    awsSecretKey: dummysecret
    rabbitmq:
      username: guest
      password: guest
    # These are only necessary if you wish to support sign up via SMS/calls
    # And require accounts at twilio.com / nexmo.com
    setTwilio: |-
      sid: "dummy"
      token: "dummy"
    setNexmo: |-
      key: "dummy"
      secret: "dummy"
cargohold:
  secrets:
    awsKeyId: "$minio_cargohold_access_key"
    awsSecretKey: "$minio_cargohold_secret_key"
    rabbitmq:
      username: guest
      password: guest
cannon:
  secrets:
    rabbitmq:
      username: guest
      password: guest
galley:
  secrets:
    rabbitmq:
      username: guest
      password: guest
    awsKeyId: dummykey
    awsSecretKey: dummysecret
gundeck:
  secrets:
    awsKeyId: dummykey
    awsSecretKey: dummysecret
    rabbitmq:
      username: guest
      password: guest
nginz:
  secrets:
    zAuth:
      publicKeys: "$zauth_public"
    # only necessary in test environments (env="staging"). See charts/nginz/README.md
    basicAuth: "<username>:<htpasswd-hashed-password>"
team-settings:
  secrets:
    # NOTE: This setting doesn't have to be changed for offline deploys as the team-settings
    # container is pre-seeded
    # It is just the empty "{}" json hashmap
    configJson: "e30K"
background-worker:
  secrets:
    rabbitmq:
      username: guest
      password: guest
EOF

echo "Writing $VALUES_DIR/coturn/prod-secrets.example.yaml"
cat <<EOF > $VALUES_DIR/coturn/prod-secrets.example.yaml
secrets:
  zrestSecrets:
    - "$zrest"
EOF


if [[ ! -f $ANSIBLE_DIR/inventory/offline/group_vars/all/secrets.yaml ]]; then
  echo "Writing $ANSIBLE_DIR/inventory/offline/group_vars/all/secrets.yaml"
  cat << EOT > $ANSIBLE_DIR/inventory/offline/group_vars/all/secrets.yaml
minio_access_key: "$minio_access_key"
minio_secret_key: "$minio_secret_key"
minio_cargohold_access_key: "$minio_cargohold_access_key"
minio_cargohold_secret_key: "$minio_cargohold_secret_key"
EOT
fi

PROM_AUTH_FILE="$VALUES_DIR/kube-prometheus-stack/prod-secrets.example.yaml"
if [[ ! -f $PROM_AUTH_FILE ]]; then
  echo "Writing $PROM_AUTH_FILE"
  cat <<EOF > $PROM_AUTH_FILE
prometheus:
  auth:
    username: admin
    password: "${prometheus_pass}"
EOF
fi
