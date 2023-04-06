#!/usr/bin/env sh

dir_path="$1"/containers-helm/
index_txt_path="$dir_path"/index.txt

ctr images pull registry.k8s.io/ingress-nginx/kube-webhook-certgen@sha256:39c5b2e3310dc4264d638ad28d9d1d96c4cbb2b2dcfb52368fe4e3c63f61e10f
ctr images export "$dir_path"/kube_webhook_certgen.tar registry.k8s.io/ingress-nginx/kube-webhook-certgen@sha256:39c5b2e3310dc4264d638ad28d9d1d96c4cbb2b2dcfb52368fe4e3c63f61e10f

ctr images pull registry.k8s.io/ingress-nginx/controller:v1.6.4
ctr images export "$dir_path"/controller_1_6_4.tar registry.k8s.io/ingress-nginx/controller:v1.6.4

sed -i /registry.k8s.io_ingress-nginx_controller_v1.6.4/d "$index_txt_path"
echo "controller_1_6_4.tar" >>  "$index_txt_path"

sed -i /registry.k8s.io/ingress-nginx/kube-webhook-certgen/d "$index_txt_path"
echo "kube_webhook_certgen.tar" >>  "$index_txt_path"
