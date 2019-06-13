#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ANSIBLE_DIR="$( cd "$SCRIPT_DIR/../ansible" && pwd )"

mkdir -p "$ANSIBLE_DIR/secrets"

zrest="${ANSIBLE_DIR}/secrets/restund_zrest_secret.txt"
zpub="${ANSIBLE_DIR}/secrets/zauth_public.txt"
zpriv="${ANSIBLE_DIR}/secrets/zauth_private.txt"
miniopub="${ANSIBLE_DIR}/secrets/minio_public.txt"
miniopriv="${ANSIBLE_DIR}/secrets/minio_private.txt"

if [[ ! -f $miniopub || ! -f $miniopriv ]]; then
    echo "Generate a secret for minio (must match the cargohold AWS keys wire-server's secrets/values)..."
    openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 > "$miniopriv"
    openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 20 > "$miniopub"
else
    echo "re-using existing minio secrets"
fi

if [[ ! -f $zrest ]]; then
    echo "Generate a secret for the restund servers (must match the turn.secret key in brig's config)..."
    openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 > "$zrest"
else
    echo "re-using existing restund secret"
fi

if [[ ! -f $zpriv || ! -f $zpub ]]; then
    echo "Generate private and public keys (used both by brig and nginz)..."
    TMP_KEYS=$(mktemp "/tmp/demo.keys.XXXXXXXXXXX")
    zauth -m gen-keypair -i 1 > "$TMP_KEYS"
    cat "$TMP_KEYS" | sed -n 's/public: \(.*\)/\1/p' > "$zpub"
    cat "$TMP_KEYS" | sed -n 's/secret: \(.*\)/\1/p' > "$zpriv"
else
    echo "re-using existing public/private keys"
fi

