#!/usr/bin/env bash
set -euo pipefail

# This will consume a list of ubuntu bionic packages (or queries), and produces
# a packages.tgz tarball, which can be statically served.

# It assumes a GPG_PRIVATE_KEY environment variable is set
# containing a key with uid gpg@wire.com
# This should contain an ascii-armoured gpg private key

usage() {
  echo "usage: GPG_PRIVATE_KEY= $0 OUTPUT-DIR" >&2
  echo "You can generate a private key as follows:" >&2
  echo "GPG_PRIVATE_KEY=\$($(dirname "$0")/generate-gpg1-key.sh)" >&2
  echo "export GPG_PRIVATE_KEY" >&2
  exit 1
}

[ $# -lt 1 ] && usage
[[ -z "${GPG_PRIVATE_KEY:-}" ]] && usage
aptly_root=$1
mkdir -p "$aptly_root"
shift


# NOTE:  These are all the packages needed for all our playbooks to succeed. This list was created by trial and error
packages=(
  python-apt
  aufs-tools
  apt-transport-https
  software-properties-common
  conntrack
  ipvsadm
  ipset
  curl
  rsync
  socat
  unzip
  e2fsprogs
  xfsprogs
  ebtables
  python3-minimal
  openjdk-8-jdk-headless
  iproute2
  procps
  libjemalloc1
  qrencode
  texlive
  latexmk
)

# shellcheck disable=SC2001
packages_=$(echo "${packages[@]}" | sed 's/\s/ \| /g')

echo "$packages_"

# NOTE: kubespray pins the exact docker and containerd versions that it
# installs. This is kept in sync with kubespray manually.
# See roles/container-engine/docker/vars/ubuntu.yml
# See roles/container-engine/containerd-common/vars/ubuntu.yml
docker_packages_kubespray="docker-ce (= 5:19.03.14~3-0~ubuntu-bionic) | docker-ce-cli (= 5:19.03.14~3-0~ubuntu-bionic) | containerd.io (= 1.3.9-1)"

# also ship a newer virsion of docker, for running our container image.
docker_packages_adminhost="docker-ce (= 5:docker-ce_20.10.17~3-0~ubuntu-bionic) | docker-ce-cli (= 5:20.10.17~3-0~ubuntu-bionic) | containerd.io (>= 1.4.1)"


GNUPGHOME=$(mktemp -d)
export GNUPGHOME
aptly_config=$(mktemp)
trap 'rm -Rf -- "$aptly_config $GNUPGHOME"' EXIT

cat > "$aptly_config" <<FOO
{ "rootDir": "$aptly_root", "downloadConcurrency": 10, "gpgProvider": "internal" }
FOO

aptly="aptly -config=${aptly_config} "

echo "Info"
gpg --version
gpg --fingerprint
gpg --no-default-keyring --keyring trustedkeys.gpg --fingerprint


# Import our signing key to our keyring
echo -e "$GPG_PRIVATE_KEY" | gpg --import

echo "Printing the public key ids..."
gpg --list-keys
echo "Printing the secret key ids..."
gpg --list-secret-keys


# import the ubuntu and docker signing keys
# TODO: Do we want to pin these better? Verify them?
curl 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x790bc7277767219c42c86f933b4fe6acc0b21f32' | gpg --no-default-keyring --keyring=trustedkeys.gpg --import
curl https://download.docker.com/linux/ubuntu/gpg | gpg --no-default-keyring --keyring=trustedkeys.gpg --import

echo "Trusted"
gpg --list-keys --no-default-keyring --keyring=trustedkeys.gpg

$aptly mirror create -architectures=amd64 -filter="${packages_}" -filter-with-deps bionic https://mirror.us.leaseweb.net/ubuntu/ bionic main universe
$aptly mirror create -architectures=amd64 -filter="${packages_}" -filter-with-deps bionic-security https://mirror.us.leaseweb.net/ubuntu/ bionic-security main universe
$aptly mirror create -architectures=amd64 -filter="${docker_packages_adminhost}" -filter-with-deps docker-ce-adminhost https://download.docker.com/linux/ubuntu bionic stable
$aptly mirror create -architectures=amd64 -filter="${docker_packages_kubespray}" -filter-with-deps docker-ce-kubespray https://download.docker.com/linux/ubuntu bionic stable

$aptly mirror update bionic
$aptly mirror update bionic-security
$aptly mirror update docker-ce-adminhost
$aptly mirror update docker-ce-kubespray

$aptly snapshot create bionic from mirror bionic
$aptly snapshot create bionic-security from mirror bionic-security
$aptly snapshot create docker-ce-adminhost from mirror docker-ce-adminhost
$aptly snapshot create docker-ce-kubespray from mirror docker-ce-kubespray

$aptly snapshot merge wire bionic bionic-security docker-ce-adminhost docker-ce-kubespray

$aptly publish snapshot -gpg-key="gpg@wire.com" -secret-keyring="$GNUPGHOME/secring.gpg" -distribution bionic wire

gpg --export gpg@wire.com -a > "$aptly_root/public/gpg"
