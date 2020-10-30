#!/usr/bin/env bash
set -eou pipefail

# This will consume a list of ubuntu bionic packages (or queries), and produces
# a packages.tgz tarball, which can be statically served.

usage() {
  echo "usage: $0" >&2
  echo " [ PACKAGE… ]" >&2
  exit 1
}

[ $# -eq 0 ] && usage

packages=$(echo "$@" | sed 's/\s/ \| /g')

export GNUPGHOME=$(mktemp -d)
aptly_root=$(mktemp -d)
aptly_config=$(mktemp)
trap 'rm -f -- "$aptly_root $aptly_config $GNUPGHOME"' EXIT

cat > "$aptly_config" <<FOO
{ "rootDir": "$aptly_root", "downloadConcurrency": 10 }
FOO

aptly="aptly -config=${aptly_config} "

# configure gpg to use a custom keyring, because aptly reads from it
gpg="gpg --keyring=$GNUPGHOME/trustedkeys.gpg --no-default-keyring"

# create a gpg signing key. This is temporary for now, in the future, there
# will be a stable signing key and official releases for this.
cat > $GNUPGHOME/keycfg <<EOF
  %echo Generating a basic OpenPGP key
  %no-protection
  Key-Type: RSA
  Key-Length: 2048
  Subkey-Type: RSA
  Subkey-Length: 2048
  Name-Real: Foo
  Name-Email: foo@wire.com
  Expire-Date: 0
  # Do a commit here, so that we can later print "done"
  %commit
  %echo done
EOF
$gpg --batch --gen-key --batch $GNUPGHOME/keycfg
$gpg --export foo@wire.com -a > $GNUPGHOME/Release.key

# import the ubuntu and docker signing keys
curl 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x790bc7277767219c42c86f933b4fe6acc0b21f32' | $gpg --import
curl https://download.docker.com/linux/ubuntu/gpg | $gpg --import
# mark them as trusted
$gpg --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | $gpg --import-ownertrust

$aptly mirror create -architectures=amd64 -filter="${packages}" -filter-with-deps ubuntu http://de.archive.ubuntu.com/ubuntu/ bionic
$aptly mirror create -architectures=amd64 -filter="docker-ce (= 5:19.03.12~3-0~ubuntu-bionic)" -filter-with-deps docker-ce https://download.docker.com/linux/ubuntu bionic

$aptly mirror update ubuntu
$aptly mirror update docker-ce

$aptly snapshot create offline-ubuntu from mirror ubuntu
$aptly snapshot create offline-docker-ce from mirror docker-ce

$aptly publish snapshot offline-ubuntu ubuntu
$aptly publish snapshot offline-docker-ce docker-ce

cp $GNUPGHOME/Release.key "$aptly_root"/public/ubuntu/gpg
cp $GNUPGHOME/Release.key "$aptly_root"/public/docker-ce/gpg

tar cvzf packages.tgz -C "$aptly_root"/public/ .
