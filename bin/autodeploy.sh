#!/usr/bin/env bash

set -Eeuo pipefail

msg() {
  echo >&2 -e "${1-}"
}

trap cleanup SIGINT SIGTERM ERR EXIT

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [--force-redeploy] [--artifact-hash string] [--target-system string]

This script deploys "Wire in a box", a functional, self-contained demo environment of Wire and it's various components.
Following this Readme: https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md

This script can either be run locally or via CI, always within the context of it's wire-server-deploy repository.

Requirements:
 * A dedicated (root) server running Ubuntu 22.04 Server with at least 16 CPU cores, 64 GiB RAM, 500 GB NVMe SSD and an (unfirewalled) public IP address.
 * Access to server via root user using an SSH keypair.

Deployment takes about 90 to 100 minutes on a Hetzner "AX41-NVMe" target system. Longer if RAID is actively syncing disks.

Running the script without any arguments requires one interaction - confirming the removal of any resources left by a previous Wire-in-a-box installation.
For CI usage, it's recommended to invoke "--force-redeploy".

It is likely desirable to invoke the script with "--artifact-hash" and / or "--target-system" as well. These are the hardcoded fallback values:
 * artifact-hash = d8fe36747614968ea73ebd43d47b99364c52f9c1
 * target-system = wiab-autodeploy.wire.link

The script will run a number of preflight checks before invoking a deployment:
 * Enumeration of required subdomain A records (see SUBDOMAINS variable).
 * Testing if SSH login via root is possible.

Available options:
-h, --help          Print this help and exit
-v, --verbose       Print script debug info
--force-redeploy    Force cleanup of previous Wire-in-a-box installation on target host
--artifact-hash     String, specifies artifact ID as created here: https://github.com/wireapp/wire-server-deploy/actions/workflows/offline.yml
                    Defaults to d8fe36747614968ea73ebd43d47b99364c52f9c1
--target-system     String, domain name used to access the target host
                    Defaults to wiab-autodeploy.wire.link
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --force-redeploy) FORCE_REDEPLOY=1 ;;
    --artifact-hash)
      ARTIFACT_HASH="${2-}"
      shift
      ;;
    --target-system)
      TARGET_SYSTEM="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done
  return 0
}

parse_params "$@"

ARTIFACT_HASH="${ARTIFACT_HASH:-d8fe36747614968ea73ebd43d47b99364c52f9c1}"
TARGET_SYSTEM="${TARGET_SYSTEM:-wiab-autodeploy.wire.link}"
FORCE_REDEPLOY="${FORCE_REDEPLOY:-0}"
SUBDOMAINS="account assets coturn federator inbucket nginz-https nginz-ssl restund sft sftd teams webapp"
SSH_PORT=22
SSH_USER=root
DEMO_USER=demo
SCRIPT_DIR=/home/"$DEMO_USER"/wire-server-deploy
DO_SYSTEM_CLEANUP=false

msg ""
msg "INFO: starting Wire-in-a-box deployment for $TARGET_SYSTEM using artifact ID $ARTIFACT_HASH"
msg ""

for SUBDOMAIN in $SUBDOMAINS; do
  if host "$SUBDOMAIN"."$TARGET_SYSTEM" >/dev/null 2>&1 ; then
    msg "INFO: DNS A record exists: $SUBDOMAIN.$TARGET_SYSTEM"
  else
    msg "ERROR: DNS A record for $SUBDOMAIN.$TARGET_SYSTEM does not exist. Exiting. Please check DNS record set."
    msg ""
  exit 1
  fi
done

if ssh -q -o ConnectTimeout=5 -p "$SSH_PORT" "$SSH_USER"@webapp."$TARGET_SYSTEM" id | grep -q "$SSH_USER"; then
  msg ""
  msg "INFO: Successfully logged into $TARGET_SYSTEM as $SSH_USER"
else
  msg "ERROR: Can't log into $TARGET_SYSTEM via SSH, please check SSH connectivity."
  exit 1
fi

system_cleanup() {
#  for VM in $(virsh list --all --name); do virsh destroy "$VM"; virsh undefine "$VM" --remove-all-storage; done
#  docker system prune -a -f
  rm -f /home/$DEMO_USER/.ssh/known_hosts
#  rm -rf /home/$DEMO_USER/wire-server-deploy
#  rm -f /home/$DEMO_USER/wire-server-deploy-static-*.tgz
}

preprovision_hetzner() {
  msg ""
  msg "INFO: running local ansible playbook for inital server deployment."
  msg "INFO: This will setup up the Hetzner system with basic defaults, download and unpack the wire-server-deploy artifact."
  sleep 5
  export LC_ALL="C.UTF-8";
  ansible-playbook ../ansible/hetzner-single-deploy.yml -e "artifact_hash=$ARTIFACT_HASH" -i $SSH_USER@webapp."$TARGET_SYSTEM", --diff --private-key="$HOME"/.ssh/hetzner_operator
}

remote_deployment() {
  msg() {
    echo >&2 -e "${1-}"
  }
  cd $SCRIPT_DIR &>/dev/null || exit 1

  bash bin/offline-vm-setup.sh
  msg ""
  while sudo virsh list --all | grep -Fq running; do
    sleep 20
    msg "INFO: VM deployment still in progress ..."
  done
  sleep 20
  msg ""
  msg "INFO: VM deployment done. Starting all VMs:"
  msg ""
  for VM in $(sudo virsh list --all --name); do sudo virsh start "$VM"; done
  sleep 60

  msg ""
  msg "INFO: Setting up offline environment (this will take a while)."
  msg ""
  # Rather than sourcing wire-server-deploy/bin/offline-env.sh, we invoke
  # the relevant commands below, declaring "d" as a function instead of an alias.
  ZAUTH_CONTAINER=$(sudo docker load -i "$SCRIPT_DIR"/containers-adminhost/quay.io_wire_zauth_*.tar | awk '{print $3}')
  export ZAUTH_CONTAINER
  WSD_CONTAINER=$(sudo docker load -i "$SCRIPT_DIR"/containers-adminhost/container-wire-server-deploy.tgz | awk '{print $3}')
  d() {
    sudo docker run --network=host -v "${SSH_AUTH_SOCK:-nonexistent}":/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v "$HOME"/.ssh:/root/.ssh -v "$PWD":/wire-server-deploy "$WSD_CONTAINER" "$@"
  }
  export -f d

  bash bin/offline-secrets.sh

  cat >ansible/inventory/offline/hosts.ini<<EOF
[all]
assethost ansible_host=192.168.122.10
kubenode1 ansible_host=192.168.122.21
kubenode2 ansible_host=192.168.122.22
kubenode3 ansible_host=192.168.122.23
ansnode1 ansible_host=192.168.122.31
ansnode2 ansible_host=192.168.122.32
ansnode3 ansible_host=192.168.122.33

[all:vars]
ansible_user = demo

[cassandra:vars]
cassandra_network_interface = enp1s0
cassandra_backup_enabled = False
cassandra_incremental_backup_enabled = False

[elasticsearch:vars]
elasticsearch_network_interface = enp1s0

[minio:vars]
minio_network_interface = enp1s0
prefix = ""
domain = "$TARGET_SYSTEM"
deeplink_title = "wire demo environment, $TARGET_SYSTEM"

[rmq-cluster:vars]
rabbitmq_network_interface = enp1s0

[kube-master]
kubenode1
kubenode2
kubenode3

[etcd]
kubenode1 etcd_member_name=etcd1
kubenode2 etcd_member_name=etcd2
kubenode3 etcd_member_name=etcd3

[kube-node]
kubenode1
kubenode2
kubenode3

[k8s-cluster:children]
kube-master
kube-node

[cassandra]
ansnode1
ansnode2
ansnode3

[cassandra_seed]
ansnode1

[elasticsearch]
ansnode1
ansnode2
ansnode3

[elasticsearch_master:children]
elasticsearch

[minio]
ansnode1
ansnode2
ansnode3

[rmq-cluster]
ansnode1
ansnode2
ansnode3
EOF

  d ./bin/offline-cluster.sh
  d kubectl get nodes -owide
  ANSNODES="ansnode1 ansnode2 ansnode3"
  for ANSNODE in $ANSNODES; do ssh -o StrictHostKeyChecking=no "$ANSNODE" "sudo bash -c '
set -eo pipefail;

#cassandra
ufw allow 9042/tcp;
ufw allow 9160/tcp;
ufw allow 7000/tcp;
ufw allow 7199/tcp;

#elasticsearch
ufw allow 9300/tcp;
ufw allow 9200/tcp;

#minio
ufw allow 9000/tcp;
ufw allow 9092/tcp;

#rabbitmq
ufw allow 5671/tcp;
ufw allow 5672/tcp;
ufw allow 4369/tcp;
ufw allow 25672/tcp;
'"; done

  d helm install cassandra-external ./charts/cassandra-external --values ./values/cassandra-external/values.yaml
  d helm install elasticsearch-external ./charts/elasticsearch-external --values ./values/elasticsearch-external/values.yaml
  d helm install minio-external ./charts/minio-external --values ./values/minio-external/values.yaml

  cp values/databases-ephemeral/prod-values.example.yaml values/databases-ephemeral/values.yaml
  d helm install databases-ephemeral ./charts/databases-ephemeral/ --values ./values/databases-ephemeral/values.yaml

  d helm install fake-aws ./charts/fake-aws --values ./values/fake-aws/prod-values.example.yaml
  d helm install demo-smtp ./charts/demo-smtp --values ./values/demo-smtp/prod-values.example.yaml
  d helm install reaper ./charts/reaper

  cp values/wire-server/prod-values.example.yaml values/wire-server/values.yaml
  sed -i "s/example.com/$TARGET_SYSTEM/g" values/wire-server/values.yaml
  sed -i "s/# - \"turn:<IP of restund1>:80\"/- \"turn:192.168.122.31:3478\"/g" values/wire-server/values.yaml
  sed -i "s/# - \"turn:<IP of restund2:80\"/- \"turn:192.168.122.32:3478\"/g" values/wire-server/values.yaml
  sed -i "s/# - \"turn:<IP of restund1>:80?transport=tcp\"/- \"turn:192.168.122.31:3478?transport=tcp\"/g" values/wire-server/values.yaml
  sed -i "s/# - \"turn:<IP of restund2>:80?transport=tcp\"/- \"turn:192.168.122.32:3478?transport=tcp\"/g" values/wire-server/values.yaml

  d helm install wire-server ./charts/wire-server --timeout=15m0s --values ./values/wire-server/values.yaml --values ./values/wire-server/secrets.yaml

  sed -i "s/example.com/$TARGET_SYSTEM/" values/webapp/prod-values.example.yaml
  d helm install webapp ./charts/webapp --values ./values/webapp/prod-values.example.yaml

  sed -i "s/example.com/$TARGET_SYSTEM/" values/team-settings/prod-values.example.yaml
  d helm install team-settings ./charts/team-settings --values ./values/team-settings/prod-values.example.yaml --values ./values/team-settings/prod-secrets.example.yaml

  sed -i "s/example.com/$TARGET_SYSTEM/" ./values/account-pages/prod-values.example.yaml
  d helm install account-pages ./charts/account-pages --values ./values/account-pages/prod-values.example.yaml

  cp values/ingress-nginx-controller/prod-values.example.yaml ./values/ingress-nginx-controller/values.yaml
  d helm install ingress-nginx-controller ./charts/ingress-nginx-controller --values ./values/ingress-nginx-controller/values.yaml

  KUBENODEIP=$(d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=IP:.status.hostIP --no-headers)
  sudo sed -i "s/define KUBENODEIP.*/define KUBENODEIP = $KUBENODEIP/" /etc/nftables.conf
  sudo systemctl restart nftables

  INGRESSNODE=$(d kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o=custom-columns=NODE:.spec.nodeName --no-headers)
  d kubectl cordon "$INGRESSNODE"

  wget https://charts.jetstack.io/charts/cert-manager-v1.13.2.tgz
  tar -C ./charts -xzf cert-manager-v1.13.2.tgz

  cp ./values/nginx-ingress-services/prod-values.example.yaml ./values/nginx-ingress-services/values.yaml
  cp ./values/nginx-ingress-services/prod-secrets.example.yaml ./values/nginx-ingress-services/secrets.yaml
  sed -i 's/useCertManager: false/useCertManager: true/g' values/nginx-ingress-services/values.yaml
  sed -i 's/certmasterEmail:/certmasterEmail: backend+wiabautodeploy@wire.com/g' values/nginx-ingress-services/values.yaml
  sed -i "s/example.com/$TARGET_SYSTEM/" values/nginx-ingress-services/values.yaml

  d kubectl create namespace cert-manager-ns
  d helm upgrade --install -n cert-manager-ns --set 'installCRDs=true' cert-manager charts/cert-manager

  d kubectl uncordon "$INGRESSNODE"

  d helm upgrade --install nginx-ingress-services charts/nginx-ingress-services -f values/nginx-ingress-services/values.yaml

  d kubectl get certificate

  cp values/sftd/prod-values.example.yaml values/sftd/values.yaml
  sed -i "s/webapp.example.com/webapp.$TARGET_SYSTEM/" values/sftd/values.yaml
  sed -i "s/sftd.example.com/sft.$TARGET_SYSTEM/" values/sftd/values.yaml
  sed -i 's/name: letsencrypt-prod/name: letsencrypt-http01/' values/sftd/values.yaml
  d helm upgrade --install sftd ./charts/sftd --values values/sftd/values.yaml
}

EXISTING_INSTALL=$(ssh -p "$SSH_PORT" "$SSH_USER"@webapp."$TARGET_SYSTEM" "ls /home/$DEMO_USER/wire-server-deploy-static-*.tgz 2>/dev/null")
EXISTING_VMS=$(ssh -p "$SSH_PORT" "$SSH_USER"@webapp."$TARGET_SYSTEM" "virsh list --all --name")
#EXISTING_VMS=$(ssh -p "$SSH_PORT" "$SSH_USER"@webapp."$TARGET_SYSTEM" "virsh list --all --name | tr '\n' ' ' | tr -d '[:blank:]'")
EXISTING_CONTAINERS=$(ssh -p "$SSH_PORT" "$SSH_USER"@webapp."$TARGET_SYSTEM" "docker ps -q --all")

if [[ "$EXISTING_INSTALL" ]]; then
  msg ""
  msg "WARNING: existing wire-server-deploy installation found: $EXISTING_INSTALL"
  DO_SYSTEM_CLEANUP=true
fi
if [[ "$EXISTING_VMS" ]]; then
  msg ""
  msg "WARNING: existing libvirt VMs found: $EXISTING_VMS"
  DO_SYSTEM_CLEANUP=true
fi
if [[ "$EXISTING_CONTAINERS" ]]; then
  msg ""
  msg "WARNING: existing Docker containers found."
  DO_SYSTEM_CLEANUP=true
fi

if [ "$DO_SYSTEM_CLEANUP" = false ]; then
  msg ""
  msg "INFO: Target system clean, no previous wire-server-deploy installation found."
fi

if [ "$DO_SYSTEM_CLEANUP" = true ] && [ "$FORCE_REDEPLOY" = 0 ]; then
  msg ""
  read -p "Do you want to wipe all wire-server-deploy components from $TARGET_SYSTEM? (y/n) " PROMPT_CLEANUP
  if [[ $PROMPT_CLEANUP == "n" || $PROMPT_CLEANUP == "N" ]]; then
    msg ""
    msg "Aborting, not cleaning up $TARGET_SYSTEM"
    msg ""
    exit 1
  fi
else
  msg ""
  msg "INFO: Cleaning up all VMs, docker resources and wire-server-deploy files on $TARGET_SYSTEM."
  msg ""
  ssh -p "$SSH_PORT" "$SSH_USER"@webapp."$TARGET_SYSTEM" "bash -s" <<EOT
$(declare -p DEMO_USER)
$(declare -f system_cleanup)
system_cleanup
EOT
fi

msg "INFO: Commencing Wire-in-a-box deployment on $TARGET_SYSTEM."
preprovision_hetzner
ssh -p "$SSH_PORT" "$DEMO_USER"@webapp."$TARGET_SYSTEM" -i "$HOME"/.ssh/hetzner_operator "bash -s" <<EOT
$(declare -p DEMO_USER TARGET_SYSTEM SCRIPT_DIR)
$(declare -f remote_deployment)
remote_deployment
EOT

msg ""
msg "INFO: Wire-in-a-box has successfully been deployed!"
msg "INFO: Access the web client interface at https://webapp.$TARGET_SYSTEM"
msg "INFO: To interact with k8s, log into $DEMO_USER@$TARGET_SYSTEM and source ./bin/offline-env.sh"
