#!/usr/bin/env bash
# migrate secrets from an old wire-server-deploy directory.

# Usage:
#
# If your secrets are in ../wire-server-deploy/values/wire-server/prod-secrets.example.yaml,
# and you are CD'd into a directory containing a wire-server-deploy package, you can just run this.
#
# Otherwise, set OLD to point to your old values file, NEW to point to your file you want to import into, and run.

set -euo pipefail

OLD="${OLD:-../wire-server-deploy/values/wire-server/prod-secrets.example.yaml}"
NEW="${NEW:-values/wire-server/prod-secrets.example.yaml}"
OUT="${NEW}.migrated"

if [ ! -f $OLD ]; then
    {
	echo "could not find OLD YAML file: $OLD"
	echo "please set OLD and NEW to point to your secrets files manually (see usage at top of script)."
	exit 1
    }
fi

if [ ! -f $NEW ]; then
    {
	echo "could not find NEW YAML file: $NEW"
	echo "please set OLD and NEW to point to your secrets files manually (see usage at top of script)."
	exit 1
    }
fi

cp "$NEW" "$OUT"

# Use YQ for reading.
PUB=$(yq -r '.brig.secrets.zAuth.publicKeys' "$OLD")
PRIV=$(yq -r '.brig.secrets.zAuth.privateKeys' "$OLD")
TURN=$(yq -r '.brig.secrets.turn.secret' "$OLD")
CH_AWS_ID=$(yq -r '.cargohold.secrets.awsKeyId' "$OLD")
CH_AWS_SECRET=$(yq -r '.cargohold.secrets.awsSecretKey' "$OLD")

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

ED25519="$ED25519" perl -0pi -e 's{(^[ \t]*ed25519:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{ED25519}))=~s/\n$//r}mse' "$OUT"

P256="$P256" perl -0pi -e 's{(^[ \t]*ecdsa_secp256r1_sha256:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{P256}))=~s/\n$//r}mse' "$OUT"

P384="$P384" perl -0pi -e 's{(^[ \t]*ecdsa_secp384r1_sha384:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{P384}))=~s/\n$//r}mse' "$OUT"

P521="$P521" perl -0pi -e 's{(^[ \t]*ecdsa_secp521r1_sha512:[ \t]*\|\n)([ \t]*)-----BEGIN PRIVATE KEY-----.*?^\2-----END PRIVATE KEY-----}{$k=$1; $i=$2; $k.join("",map{"$i$_\n"}split(/\n/,$ENV{P521}))=~s/\n$//r}mse' "$OUT"

PUB="$PUB" perl -0pi -e 's{(nginz:\n.*?zAuth:\n(?:.*\n)*?^[ \t]*publicKeys:[ \t]*)[^\n]+}{$1 . qq{"$ENV{PUB}"}}me' "$OUT"

diff -u "$NEW" "$OUT" || true

read -rp "Replace $NEW? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] && mv "$OUT" "$NEW" || echo "Kept: $OUT"
