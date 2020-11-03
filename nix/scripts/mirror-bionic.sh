#!/usr/bin/env bash
set -eou pipefail

# This will consume a list of ubuntu bionic packages (or queries), and produces
# a packages.tgz tarball, which can be statically served.

# It assumes a GPG_PRIVATE_KEY environment variable is set
# containing a key with uid gpg@wire.com
# This should contain an ascii-armoured gpg private key

usage() {
  echo "usage: $0 OUTPUT-DIR [ PACKAGES … ]" >&2
  exit 1
}

[ $# -lt 1 ] && usage
aptly_root=$1
rm -R "$aptly_root" || true
mkdir -p "$aptly_root"
shift

# shellcheck disable=SC2001
packages=$(echo "$@" | sed 's/\s/ \| /g')

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
aptly_config=$(mktemp)
trap 'rm -Rf -- "$aptly_config $GNUPGHOME"' EXIT

cat > "$aptly_config" <<FOO
{ "rootDir": "$aptly_root", "downloadConcurrency": 10 }
FOO

aptly="aptly -config=${aptly_config} "

# configure gpg to use a custom keyring, because aptly reads from it
gpg="gpg --keyring=$GNUPGHOME/trustedkeys.gpg --no-default-keyring"

if [[ -z "${GPG_PRIVATE_KEY:-}" ]]; then
  echo "*** WARNING: GPG_PRIVATE_KEY not set, creating a ephemeral key***" >&2
  GPG_PRIVATE_KEY=$(generate-gpg1-key)
  export GPG_PRIVATE_KEY
fi
echo -e "$GPG_PRIVATE_KEY" | $gpg --import

# import the ubuntu and docker signing keys
curl 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x790bc7277767219c42c86f933b4fe6acc0b21f32' | $gpg --import
curl https://download.docker.com/linux/ubuntu/gpg | $gpg --import
# mark them as trusted
$gpg --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | $gpg --import-ownertrust

$aptly mirror create -architectures=amd64 -filter="${packages}" -filter-with-deps ubuntu http://de.archive.ubuntu.com/ubuntu/ bionic
$aptly mirror create -architectures=amd64 -filter="docker-ce (= 5:19.03.12~3-0~ubuntu-bionic) | docker-ce-cli (= 5:19.03.12~3-0~ubuntu-bionic) | containerd.io (=1.2.13-2)" -filter-with-deps docker-ce https://download.docker.com/linux/ubuntu bionic stable

$aptly mirror update ubuntu
$aptly mirror update docker-ce

$aptly snapshot create offline-ubuntu from mirror ubuntu
$aptly snapshot create offline-docker-ce from mirror docker-ce

$aptly publish snapshot offline-ubuntu ubuntu
$aptly publish snapshot offline-docker-ce docker-ce

$gpg --export gpg@wire.com -a > "$GNUPGHOME"/Release.key
cp "$GNUPGHOME"/Release.key "$aptly_root"/public/ubuntu/gpg
cp "$GNUPGHOME"/Release.key "$aptly_root"/public/docker-ce/gpg
