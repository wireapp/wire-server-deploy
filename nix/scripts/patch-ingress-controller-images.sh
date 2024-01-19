#!/usr/bin/env sh

dir_path="$1"/containers-helm/
index_txt_path="$dir_path"/index.txt

sudo ctr images pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20220916-gd32f8c343
sudo ctr images export "$dir_path"/kube_webhook_certgen.tar registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20220916-gd32f8c343

sudo ctr images pull registry.k8s.io/ingress-nginx/controller:v1.6.4
sudo ctr images export "$dir_path"/controller_1_6_4.tar registry.k8s.io/ingress-nginx/controller:v1.6.4

sed -i "/registry\.k8s\.io_ingress-nginx_controller_v1.6.4/d" "$index_txt_path"
echo "controller_1_6_4.tar" >>  "$index_txt_path"

sed -i "/registry\.k8s\.io_ingress-nginx_kube-webhook-certgen/d" "$index_txt_path"
echo "kube_webhook_certgen.tar" >>  "$index_txt_path"
