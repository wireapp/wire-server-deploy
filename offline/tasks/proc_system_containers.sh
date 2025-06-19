#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Creating system containers tarball ${OUTPUT_DIR} ..."

function list-system-containers() {
# These are manually updated with values from
# https://github.com/kubernetes-sigs/kubespray/blob/release-2.24/roles/kubespray-defaults/defaults/main/download.yml
# TODO: Automate this. This is very wieldy :)
  cat <<EOF
registry.k8s.io/pause:3.9
registry.k8s.io/coredns/coredns:v1.11.4
registry.k8s.io/dns/k8s-dns-node-cache:1.22.28
registry.k8s.io/cpa/cluster-proportional-autoscaler:v1.8.8
registry.k8s.io/metrics-server/metrics-server:v0.7.2
registry.k8s.io/ingress-nginx/controller:v1.12.1
registry.k8s.io/kube-apiserver:v1.29.10
registry.k8s.io/kube-controller-manager:v1.29.10
registry.k8s.io/kube-scheduler:v1.29.10
registry.k8s.io/kube-proxy:v1.29.10
quay.io/coreos/etcd:v3.5.16
quay.io/calico/node:v3.27.4
quay.io/calico/cni:v3.27.4
quay.io/calico/pod2daemon-flexvol:v3.27.4
quay.io/calico/kube-controllers:v3.27.4
quay.io/calico/typha:v3.27.4
quay.io/calico/apiserver:v3.27.4
quay.io/jetstack/cert-manager-controller:v1.16.3
quay.io/jetstack/cert-manager-cainjector:v1.16.3
quay.io/jetstack/cert-manager-webhook:v1.16.3
quay.io/jetstack/cert-manager-startupapicheck:v1.16.3
docker.io/library/nginx:1.25.4-alpine
bats/bats:1.11.1
cr.step.sm/smallstep/step-ca:0.25.3-rc7
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b53cabe0
docker.io/bitnami/os-shell:12-debian-12-r47
docker.io/bitnami/postgresql:14.5.0-debian-11-r24
EOF
}

list-system-containers | create-container-dump "${OUTPUT_DIR}"/containers-system
tar cf "${OUTPUT_DIR}"/containers-system.tar -C "${OUTPUT_DIR}" containers-system
mv "${OUTPUT_DIR}/containers-system/images.json" "${OUTPUT_DIR}"/versions/containers_system_images.json
rm -r "${OUTPUT_DIR}"/containers-system
