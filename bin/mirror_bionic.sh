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

aptly_root=$(mktemp -d)
aptly_config=$(mktemp)
trap 'rm -f -- "$aptly_root $aptly_config"' EXIT

cat > "$aptly_config" <<FOO
{ "rootDir": "$aptly_root", "downloadConcurrency": 10, "gpgDisableSign": true, "gpgDisableVerify": true }
FOO

aptly="aptly -config=${aptly_config} "

$aptly mirror create -ignore-signatures -architectures=amd64 -filter="${packages}" -filter-with-deps ubuntu http://de.archive.ubuntu.com/ubuntu/ bionic
$aptly mirror -ignore-signatures update ubuntu

$aptly snapshot create offline from mirror ubuntu
$aptly publish snapshot -skip-signing offline

tar cvzf packages.tgz -C "$aptly_root"/public/ .
