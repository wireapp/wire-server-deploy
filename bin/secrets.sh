#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPLEVEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Generates fresh zauth, TURN/restund, nginx/basic-auth and minio secrets as one-secret-per file. This can be useful in ansible-based deployments.
# Then templates those secrets together in a secrets.yaml file for use in helm deployments.
# USAGE:
# ./bin/secrets.sh [ path-to-new-directory-for-secrets-output | default ./secrets_cache ]

OUTPUT_DIR="${1:-"$TOPLEVEL_DIR/secrets_cache"}"
ZAUTH_CONTAINER="${ZAUTH_CONTAINER:-quay.io/wire/zauth:latest}"

mkdir -p "$OUTPUT_DIR"

zrest="${OUTPUT_DIR}/restund_zrest_secret.txt"
zpub="${OUTPUT_DIR}/zauth_public.txt"
zpriv="${OUTPUT_DIR}/zauth_private.txt"
miniopub="${OUTPUT_DIR}/minio_public.txt"
miniopriv="${OUTPUT_DIR}/minio_private.txt"
NGINZ_BASIC_CONFIG="${OUTPUT_DIR}/nginz_basic_auth_config.txt"
NGINZ_BASIC_PW="${OUTPUT_DIR}/nginz_basic_auth_password.txt"
NGINZ_BASIC_USER="${OUTPUT_DIR}/nginz_basic_auth_user.txt"

command -v htpasswd >/dev/null 2>&1 || {
    echo >&2 "htpasswd is not installed, aborting. Maybe try the httpd-tools or apache-utils packages?"
    exit 1
}
command -v openssl >/dev/null 2>&1 || {
    echo >&2 "openssl is not installed, aborting."
    exit 1
}
command -v zauth >/dev/null 2>&1 || command -v docker >/dev/null 2>&1 || {
    echo >&2 "zauth is not installed, and docker is also not installed, aborting. See wire-server and compile zauth, or install docker and try using \"docker run --rm quay.io/wire/zauth:latest\" instead."
    exit 1
}

if [[ ! -f $miniopub || ! -f $miniopriv ]]; then
    echo "Generate a secret for minio (must match the cargohold AWS keys wire-server's secrets/values)..."
    openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 >"$miniopriv"
    openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 20 >"$miniopub"
else
    echo "re-using existing minio secrets"
fi

if [[ ! -f $zrest ]]; then
    echo "Generate a secret for the restund servers (must match the turn.secret key in brig's config)..."
    openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 >"$zrest"
else
    echo "re-using existing restund secret"
fi

if [[ ! -f $zpriv || ! -f $zpub ]]; then
    echo "Generate private and public keys (used both by brig and nginz)..."
    TMP_KEYS=$(mktemp "/tmp/demo.keys.XXXXXXXXXXX")
    zauth -m gen-keypair >"$TMP_KEYS" 2>/dev/null ||
        docker run --rm "$ZAUTH_CONTAINER" -m gen-keypair >"$TMP_KEYS"
    cat "$TMP_KEYS" | sed -n 's/public: \(.*\)/\1/p' >"$zpub"
    cat "$TMP_KEYS" | sed -n 's/secret: \(.*\)/\1/p' >"$zpriv"
else
    echo "re-using existing public/private keys"
fi

if [[ ! -f $NGINZ_BASIC_PW || ! -f $NGINZ_BASIC_CONFIG || ! -f $NGINZ_BASIC_USER ]]; then
    echo "creating basic auth password for nginz..."
    echo basic-auth-user >"$NGINZ_BASIC_USER"
    openssl rand -base64 64 | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 42 >"$NGINZ_BASIC_PW"
    htpasswd -cb "$NGINZ_BASIC_CONFIG" "$(cat "$NGINZ_BASIC_USER")" "$(cat "$NGINZ_BASIC_PW")"
else
    echo "re-using basic auth password for nginz"
fi

echo ""
echo "1. You can use the generated $OUTPUT_DIR/secrets_ansible.yaml file as part of your ansible group_vars/. Copy this to your inventory."
echo "2. You could use the generated"
echo "   $OUTPUT_DIR/secrets.yaml"
echo "as a basis for your helm overrides (copy to location of your choosing then adjust as needed)"

echo "
# helm_vars/wire-server/secrets.yaml
nginz:
    secrets:
        # Note: basicAuth on some internal endpoints only active if
        # nginz.env == staging, otherwise no effect
        basicAuth: $(cat "$NGINZ_BASIC_CONFIG")
        zAuth:
            publicKeys: $(cat "$zpub")

cannon:
  secrets:
    nginz:
      zAuth:
        publicKeys: $(cat "$zpub")
brig:
    secrets:
        zAuth:
            publicKeys: $(cat "$zpub")
            privateKeys: $(cat "$zpriv")
        turn:
            secret: $(cat "$zrest")
        smtpPassword: dummyPassword
        # these only need to be changed if using real AWS services
        awsKeyId: dummykey
        awsSecretKey: dummysecret

cargohold:
    secrets:
        awsKeyId: dummykey
        awsSecretKey: dummysecret
galley:
    secrets:
        awsKeyId: dummykey
        awsSecretKey: dummysecret
gundeck:
    secrets:
        awsKeyId: dummykey
        awsSecretKey: dummysecret
proxy:
    secrets:
        proxy_config: |-
            secrets {
                    youtube    = ...
                    googlemaps = ...
                    soundcloud = ...
                    giphy      = ...
                    spotify    = Basic ...
            }
" >"$OUTPUT_DIR/secrets.yaml"

echo "
restund_zrest_secret: \"$(cat "$zrest")\"
minio_access_key: \"$(cat "$miniopub")\"
minio_secret_key: \"$(cat "$miniopriv")\"
" >"$OUTPUT_DIR/secrets_ansible.yaml"
