#!/usr/bin/env bash
# migrate secrets from an old wire-server-deploy directory.

# Usage:
#
# If your secrets are in ../wire-server-deploy/values/wire-server/prod-secrets.example.yaml,
# and you are CD'd into a directory containing a wire-server-deploy package, you can just run this.
#
# Otherwise, set OLD to point to your old values file, NEW to point to your file you want to import into, and run.

set -euo pipefail

OLD="${OLD:-../wire-server-deploy/values/wire-server/secrets.yaml}"
NEW="${NEW:-values/wire-server/prod-secrets.example.yaml}"
NEWCOTURN="${NEWCOTURN:-values/coturn/prod-secrets.example.yaml}"

if [ ! -f $OLD ]; then
    {
	echo "could not find OLD YAML file: $OLD"
	echo "please set OLD to point to your in-use wire-server secrets file manually (see usage at top of script)."
	exit 1
    }
fi

if [ ! -f $NEW ]; then
    {
	echo "could not find NEW YAML file: $NEW"
	echo "please set NEW to point to your new wire-server secrets files manually (see usage at top of script)."
	exit 1
    }
fi
OUT="${NEW}.migrated"

if [ ! -f $NEWCOTURN ]; then
    {
	echo "could not find NEWCOTURN YAML file: $NEW"
	echo "please set NEWCOTURN to point to your new coturn secrets files manually (see usage at top of script)."
	exit 1
    }
fi
OUTCOTURN="${NEWCOTURN}.migrated"

cp "$NEW" "$OUT"
cp "$NEWCOTURN" "$OUTCOTURN"

# Use YQ for reading.
PUB=$(yq -r '.brig.secrets.zAuth.publicKeys' "$OLD")
PRIV=$(yq -r '.brig.secrets.zAuth.privateKeys' "$OLD")
TURN=$(yq -r '.brig.secrets.turn.secret' "$OLD")

# Cargohold AWS access.
CH_AWS_ID=$(yq -r '.cargohold.secrets.awsKeyId' "$OLD")
CH_AWS_SECRET=$(yq -r '.cargohold.secrets.awsSecretKey' "$OLD")

# The Postgres secret.
PG_PASSWORD=$(yq -r '.brig.secrets.pgPassword' "$OLD")

# Whole keys.
ED25519=$(yq -r '.galley.secrets.mlsPrivateKeys.removal.ed25519' "$OLD")
P256=$(yq -r '.galley.secrets.mlsPrivateKeys.removal.ecdsa_secp256r1_sha256' "$OLD")
P384=$(yq -r '.galley.secrets.mlsPrivateKeys.removal.ecdsa_secp384r1_sha384' "$OLD")
P521=$(yq -r '.galley.secrets.mlsPrivateKeys.removal.ecdsa_secp521r1_sha512' "$OLD")

# Use perl for writing into the new file. This is to prevent YQ from eating our empty lines, in the yaml.
PUB="$PUB" perl -0pi -e 's{(brig:\n(?:.*\n)*?[ \t]+zAuth:\n(?:.*\n)*?^[ \t]+publicKeys:[ \t]*)[^\n]+}{$1.qq{"$ENV{PUB}"}}me' "$OUT"
PRIV="$PRIV" perl -0pi -e 's{(brig:\n(?:.*\n)*?[ \t]+zAuth:\n(?:.*\n)*?^[ \t]+privateKeys:[ \t]*)[^\n]+}{$1.qq{"$ENV{PRIV}"}}me' "$OUT"
TURN="$TURN" perl -0pi -e 's{(brig:\n(?:.*\n)*?[ \t]+turn:\n(?:.*\n)*?^[ \t]+secret:[ \t]*)[^\n]+}{$1.qq{"$ENV{TURN}"}}me' "$OUT"

CH_AWS_ID="$CH_AWS_ID" perl -0pi -e 's{(cargohold:\n(?:.*\n)*?^[ \t]+awsKeyId:[ \t]*)[^ \n]+}{$1.qq{"$ENV{CH_AWS_ID}"}}me' "$OUT"
CH_AWS_SECRET="$CH_AWS_SECRET" perl -0pi -e 's{(cargohold:\n(?:.*\n)*?^[ \t]+awsSecretKey:[ \t]*)[^ \n]+}{$1.qq{"$ENV{CH_AWS_SECRET}"}}me' "$OUT"

PG_PASSWORD="$PG_PASSWORD" perl -0pi -e 's{(brig:\n(?:.*\n)*?^[ \t]+secrets:\n(?:.*\n)*?^[ \t]+pgPassword:[ \t]*)[^\n]+}{$1.$ENV{PG_PASSWORD}}me' "$OUT"
PG_PASSWORD="$PG_PASSWORD" perl -0pi -e 's{(galley:\n(?:.*\n)*?^[ \t]+secrets:\n(?:.*\n)*?^[ \t]+pgPassword:[ \t]*)[^\n]+}{$1.$ENV{PG_PASSWORD}}me' "$OUT"
PG_PASSWORD="$PG_PASSWORD" perl -0pi -e 's{(background-worker:\n(?:.*\n)*?^[ \t]+secrets:\n(?:.*\n)*?^[ \t]+pgPassword:[ \t]*)[^\n]+}{$1.$ENV{PG_PASSWORD}}me' "$OUT"

ED25519="$ED25519" perl -0pi -e 's{(^[ \t]*ed25519:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{ED25519}))=~s/\n$//r}mse' "$OUT"
P256="$P256" perl -0pi -e 's{(^[ \t]*ecdsa_secp256r1_sha256:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{P256}))=~s/\n$//r}mse' "$OUT"
P384="$P384" perl -0pi -e 's{(^[ \t]*ecdsa_secp384r1_sha384:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{P384}))=~s/\n$//r}mse' "$OUT"
P521="$P521" perl -0pi -e 's{(^[ \t]*ecdsa_secp521r1_sha512:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{P521}))=~s/\n$//r}mse' "$OUT"

PUB="$PUB" perl -0pi -e 's{(nginz:\n.*?zAuth:\n(?:.*\n)*?^[ \t]*publicKeys:[ \t]*)[^\n]+}{$1 . qq{"$ENV{PUB}"}}me' "$OUT"

if diff -u "$NEW" "$OUT" ; then
    echo "no difference found in wire-server configuration."
    rm -f "$OUT"
else
    read -rp "Replace $NEW? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] && mv "$OUT" "$NEW" || echo "Kept: $OUT"
fi

TURN="$TURN" perl -0pi -e 's{(^[ \t]*zrestSecrets:\n[ \t]*-[ \t]*)"[^"]*"}{$1.qq{"$ENV{TURN}"}}me' "$OUTCOTURN"

if diff -u "$NEWCOTURN" "$OUTCOTURN"; then
    echo "no difference found in coturn configuration."
    rm -f "$OUTCOTURN"
else
    read -rp "Replace $NEWCOTURN? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] && mv "$OUTCOTURN" "$NEWCOTURN" || echo "Kept: $OUTCOTURN"
fi
