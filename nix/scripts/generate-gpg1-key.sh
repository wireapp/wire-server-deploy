#!/usr/bin/env bash
set -eou pipefail

# This will create a gpg1 private key with uid gpg@wire.com, and output it as
# ascii-armoured to stdout.

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -Rf -- "$GNUPGHOME"' EXIT

# configure gpg to use a custom keyring, because aptly reads from it
gpg="gpg --keyring=$GNUPGHOME/trustedkeys.gpg --no-default-keyring"

# create a gpg signing key. This is temporary for now, in the future, there
# will be a stable signing key and official releases for this.
cat > "$GNUPGHOME"/keycfg <<EOF
  %echo Generating a basic OpenPGP key
  %no-protection
  Key-Type: RSA
  Key-Length: 2048
  Subkey-Type: RSA
  Subkey-Length: 2048
  Name-Real: Wire Swiss GmbH
  Name-Email: gpg@wire.com
  Expire-Date: 6m
  # Do a commit here, so that we can later print "done"
  %commit
  %echo done
EOF
$gpg --batch --gen-key --batch "$GNUPGHOME"/keycfg
# print the private key to stdout
$gpg --export-secret-keys -a gpg@wire.com