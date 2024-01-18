#!/usr/bin/env bash
set -euo pipefail

# This will consume a list of ubuntu jammy packages (or queries), and produces
# a packages.tgz tarball, which can be statically served.

# It assumes a GPG_PRIVATE_KEY environment variable is set
# containing a key with uid gpg@wire.com
# This should contain an ascii-armoured gpg private key

usage() {
  echo "usage: GPG_PRIVATE_KEY= $0 OUTPUT-DIR" >&2
  echo "You can generate a private key as follows:" >&2
  echo "GPG_PRIVATE_KEY=\$(generate-gpg1-key)" >&2
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
  python3-apt
  python3-netaddr
  python3-jmespath
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
  libjemalloc2
  qrencode
  texlive
  latexmk
  libopts25
  ntp
  libc6
  libseccomp2
  iptables
  bash-completion
  logrotate
  cron
  crontab
  ufw
  netcat
  telnet
  less
  traceroute
  strace
  iputils-ping
  nano
  vi
  tcpdump
  gnupg
  # Dependencies for the rabbitmq-server package
  erlang-base
  erlang-asn1
  erlang-crypto
  erlang-eldap
  erlang-ftp
  erlang-inets
  erlang-mnesia
  erlang-os-mon
  erlang-parsetools
  erlang-public-key
  erlang-runtime-tools
  erlang-snmp
  erlang-ssl
  erlang-syntax-tools
  erlang-tftp
  erlang-tools
  erlang-xmerl
  rabbitmq-server
)

# shellcheck disable=SC2001
packages_=$(echo "${packages[@]}" | sed 's/\s/ \| /g')

echo "$packages_"

# NOTE: kubespray pins the exact docker and containerd versions that it
# installs. This is kept in sync with kubespray manually.
# See roles/container-engine/docker/vars/ubuntu.yml
# See roles/container-engine/containerd-common/vars/ubuntu.yml
docker_packages="docker-ce (= 5:20.10.20~3-0~ubuntu-jammy) | docker-ce-cli (= 5:20.10.20~3-0~ubuntu-jammy) | containerd.io (= 1.6.8-1)"
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
curl 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf6ecb3762474eda9d21b7022871920d1991bc93c' | gpg --no-default-keyring --keyring=trustedkeys.gpg --import
curl https://download.docker.com/linux/ubuntu/gpg | gpg --no-default-keyring --keyring=trustedkeys.gpg --import
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | gpg --no-default-keyring --keyring=trustedkeys.gpg --import
curl -1sLf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf77f1eda57ebb1cc" | gpg --no-default-keyring --keyring=trustedkeys.gpg --import
curl -1sLf "https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey" | gpg --no-default-keyring --keyring=trustedkeys.gpg --import

echo "Trusted"
gpg --list-keys --no-default-keyring --keyring=trustedkeys.gpg

$aptly mirror create -architectures=amd64 -filter="${packages_}" -filter-with-deps jammy http://de.archive.ubuntu.com/ubuntu/ jammy main universe
$aptly mirror create -architectures=amd64 -filter="${packages_}" -filter-with-deps jammy-security http://de.archive.ubuntu.com/ubuntu/ jammy-security main universe
$aptly mirror create -architectures=amd64 -filter="${packages_}" -filter-with-deps jammy-updates http://de.archive.ubuntu.com/ubuntu/ jammy-updates main universe
$aptly mirror create -architectures=amd64 -filter="${docker_packages}" -filter-with-deps docker-ce https://download.docker.com/linux/ubuntu jammy stable

$aptly mirror update jammy
$aptly mirror update jammy-security
$aptly mirror update jammy-updates
$aptly mirror update docker-ce

$aptly snapshot create jammy from mirror jammy
$aptly snapshot create jammy-security from mirror jammy-security
$aptly snapshot create jammy-updates from mirror jammy-updates
$aptly snapshot create docker-ce from mirror docker-ce

$aptly snapshot merge wire jammy jammy-security jammy-updates docker-ce

$aptly publish snapshot -gpg-key="gpg@wire.com" -secret-keyring="$GNUPGHOME/secring.gpg" -distribution jammy wire

gpg --export gpg@wire.com -a > "$aptly_root/public/gpg"
