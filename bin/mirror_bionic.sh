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
$aptly mirror create -ignore-signatures -architectures=amd64 -filter="docker-ce (= 5:19.03.12~3-0~ubuntu-bionic)" -filter-with-deps docker https://download.docker.com/linux/ubuntu bionic

$aptly mirror -ignore-signatures update ubuntu
$aptly mirror -ignore-signatures update docker

$aptly snapshot create offline-ubuntu from mirror ubuntu
$aptly snapshot create offline-docker from mirror docker

$aptly publish snapshot -skip-signing offline-ubuntu ubuntu
$aptly publish snapshot -skip-signing offline-docker docker

tar cvzf packages.tgz -C "$aptly_root"/public/ .
