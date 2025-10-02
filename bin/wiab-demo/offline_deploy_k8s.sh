#!/usr/bin/env bash
# shellcheck disable=SC2087
set -Eeuo pipefail

BASE_DIR="/wire-server-deploy"
TARGET_SYSTEM="example.com"
CERT_MASTER_EMAIL="certmaster@example.com"

# make sure these align with the iptables rules, has to be manually updated
SFT_NODE="K8S_SFT_NODE"
# picking a node for nginx
NGINX_K8S_NODE="NGINX_K8S_NODE"
# picking a node for coturn
COTURN_NODE="K8S_COTURN_NODE"

# this IP should match the DNS A record for TARGET_SYSTEM
# keeping it empty to be replaced
HOST_IP="WIRE_IP"

# it creates the values.yaml from prod-values.example.yaml and secrets.yaml from prod-secrets.example.yaml, it works on the directory $BASE_DIR"/values/ in the bundle
process_charts() {  
  
  ENV=$1

  if [ "$ENV" != "prod" ] && [ "$ENV" != "demo" ]; then
    echo "ENV is neither prod nor demo"
    exit 1
  fi 

  for chart_dir in "$BASE_DIR"/values/*/; do

    if [[ -d "$chart_dir" ]]; then
      if [[ -f "$chart_dir/${ENV}-values.example.yaml" ]]; then
        # assuming if the values.yaml exist, it won't replace it again to make it idempotent
        if [[ ! -f "$chart_dir/values.yaml" ]]; then
          cp "$chart_dir/${ENV}-values.example.yaml" "$chart_dir/values.yaml"
          echo "Used template ${ENV}-values.example.yaml to create $chart_dir/values.yaml"
        fi
      fi

      if [[ -f "$chart_dir/${ENV}-secrets.example.yaml" ]]; then
      # assuming if the secrets.yaml exist, it won't replace it again to make it idempotent
        if [[ ! -f "$chart_dir/secrets.yaml" ]]; then
          cp "$chart_dir/${ENV}-secrets.example.yaml" "$chart_dir/secrets.yaml"
          echo "Used template ${ENV}-secrets.example.yaml to create $chart_dir/secrets.yaml"
        fi
      fi

    fi

  done
}

# selectively setting values of following charts which requires additional values
# wire-server, webapp, team-settings, account-pages, nginx-ingress-services, ingress-nginx-controller, sftd and coturn
process_values() {
  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf $TEMP_DIR' EXIT

  # to find IP address of coturn NODE
  COTURN_NODE_IP=$(kubectl get node $COTURN_NODE -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

  # Fixing the hosts with TARGET_SYSTEM and setting the turn server
  sed -e "s/example.com/$TARGET_SYSTEM/g" \
      "$BASE_DIR/values/wire-server/values.yaml" > "$TEMP_DIR/wire-server-values.yaml"

  # fixing the turnStatic values
  yq -i -Y ".brig.turnStatic.v2 = [\"turn:$HOST_IP:3478\", \"turn:$HOST_IP:3478?transport=tcp\"]" "$TEMP_DIR/wire-server-values.yaml"

  # Fixing the hosts in webapp team-settings and account-pages charts
  for chart in webapp team-settings account-pages; do
    sed "s/example.com/$TARGET_SYSTEM/g" "$BASE_DIR/values/$chart/values.yaml" > "$TEMP_DIR/$chart-values.yaml"
  done

  # Setting certManager and DNS records
  sed -e 's/useCertManager: false/useCertManager: true/g' \
    -e "/certmasterEmail:$/s/certmasterEmail:/certmasterEmail: $CERT_MASTER_EMAIL/" \
    -e "s/example.com/$TARGET_SYSTEM/" \
    "$BASE_DIR/values/nginx-ingress-services/values.yaml" > "$TEMP_DIR/nginx-ingress-services-values.yaml"

  # adding nodeSelector for ingress controller as it should run as Deployment in the k8s cluster i.e. lack of external load balancer
  sed -e 's/kind: DaemonSet/kind: Deployment/' \
      "$BASE_DIR/values/ingress-nginx-controller/values.yaml" > "$TEMP_DIR/ingress-nginx-controller-values.yaml"
  if ! grep -q "kubernetes.io/hostname: $NGINX_K8S_NODE" "$TEMP_DIR/ingress-nginx-controller-values.yaml"; then
    echo -e "    nodeSelector:\n      kubernetes.io/hostname: $NGINX_K8S_NODE" >> "$TEMP_DIR/ingress-nginx-controller-values.yaml"
  fi 

  # Fixing SFTD hosts and setting the cert-manager to http01
  sed -e "s/webapp.example.com/webapp.$TARGET_SYSTEM/" \
      -e "s/sftd.example.com/sftd.$TARGET_SYSTEM/" \
      -e 's/name: letsencrypt-prod/name: letsencrypt-http01/' \
      "$BASE_DIR/values/sftd/values.yaml" > "$TEMP_DIR/sftd-values.yaml"

  # Creating coturn values and secrets
  ZREST_SECRET=$(yq '.brig.secrets.turn.secret' "$BASE_DIR/values/wire-server/secrets.yaml" | tr -d '"')
  cat >"$TEMP_DIR/coturn-secrets.yaml"<<EOF
secrets:
  zrestSecrets:
    - "$ZREST_SECRET"
EOF

  cat >"$TEMP_DIR/coturn-values.yaml"<<EOF
nodeSelector:
  wire.com/role: coturn

coturnTurnListenIP: "$COTURN_NODE_IP"
coturnTurnRelayIP: "$COTURN_NODE_IP"
coturnTurnExternalIP: '$HOST_IP'
EOF

  # Compare and copy files if different
  for file in wire-server-values.yaml webapp-values.yaml team-settings-values.yaml account-pages-values.yaml \
              nginx-ingress-services-values.yaml ingress-nginx-controller-values.yaml sftd-values.yaml; do
    if ! cmp -s "$TEMP_DIR/$file" "$BASE_DIR/values/${file%-values.yaml}/values.yaml"; then
      cp "$TEMP_DIR/$file" "$BASE_DIR/values/${file%-values.yaml}/values.yaml"
      echo "Updating  $BASE_DIR/values/${file%-values.yaml}/values.yaml"
    fi
  done

  if ! cmp -s "$TEMP_DIR/coturn-secrets.yaml" "$BASE_DIR/values/coturn/secrets.yaml"; then
    cp "$TEMP_DIR/coturn-secrets.yaml" "$BASE_DIR/values/coturn/secrets.yaml"
    echo "Updating $BASE_DIR/values/coturn/secrets.yaml"
  fi

  if ! cmp -s "$TEMP_DIR/coturn-values.yaml" "$BASE_DIR/values/coturn/values.yaml"; then
    cp "$TEMP_DIR/coturn-values.yaml" "$BASE_DIR/values/coturn/values.yaml"
    echo "Updating $BASE_DIR/values/coturn/values.yaml"
  fi
}

deploy_charts() {
  local charts=("$@")
  echo "Following charts will be deployed: ${charts[*]}"

  for chart in "${charts[@]}"; do
    chart_dir="$BASE_DIR/charts/$chart"
    values_file="$BASE_DIR/values/$chart/values.yaml"
    secrets_file="$BASE_DIR/values/$chart/secrets.yaml"

    if [[ ! -d "$chart_dir" ]]; then
      echo "Error: Chart directory $chart_dir does not exist."
      continue
    fi

    if [[ ! -f "$values_file" ]]; then
      echo "Warning: Values file $values_file does not exist. Deploying without values."
      values_file=""
    fi

    if [[ ! -f "$secrets_file" ]]; then
      secrets_file=""
    fi

    helm_command="helm upgrade --install --wait --timeout=15m0s $chart $chart_dir"

    if [[ -n "$values_file" ]]; then
      helm_command+=" --values $values_file"
    fi

    if [[ -n "$secrets_file" ]]; then
      helm_command+=" --values $secrets_file"
    fi

    echo "Deploying $chart as $helm_command"
    eval "$helm_command"
  done

  # display running pods post deploying all helm charts in default namespace
  kubectl get pods --sort-by=.metadata.creationTimestamp
}

deploy_cert_manager() {

  kubectl get namespace cert-manager-ns || kubectl create namespace cert-manager-ns
  helm upgrade --install -n cert-manager-ns cert-manager  $BASE_DIR/charts/cert-manager --values "$BASE_DIR/values/cert-manager/values.yaml"

  # display running pods
  kubectl get pods --sort-by=.metadata.creationTimestamp -n cert-manager-ns
}

deploy_calling_services() {

  echo "Deploying sftd and coturn"
  # select the node to deploy sftd
  kubectl label node $SFT_NODE wire.com/role=sftd --overwrite
  helm upgrade --install sftd $BASE_DIR/charts/sftd --set 'nodeSelector.wire\.com/role=sftd' --set 'node_annotations="{'wire\.com/external-ip': '"$HOST_IP"'}"' --values  $BASE_DIR/values/sftd/values.yaml

  kubectl label node $COTURN_NODE wire.com/role=coturn --overwrite
  kubectl annotate node $COTURN_NODE wire.com/external-ip="$HOST_IP" --overwrite
  helm upgrade --install coturn ./charts/coturn --values  $BASE_DIR/values/coturn/values.yaml --values  $BASE_DIR/values/coturn/secrets.yaml
}

# if required, this function can be run manually
run_manually() {
# process_charts can process demo or prod values
process_charts "demo"
process_values
# deploying cert manager to issue certs, by default letsencrypt-http01 issuer is configured
deploy_cert_manager

# deploying with external datastores, useful for prod setup
#deploy_charts cassandra-external elasticsearch-external minio-external fake-aws smtp rabbitmq databases-ephemeral reaper wire-server webapp account-pages team-settings smallstep-accomp ingress-nginx-controller nginx-ingress-services

# deploying with ephemeral datastores, useful for all k8s setup withou external datastore requirement
deploy_charts fake-aws smtp rabbitmq databases-ephemeral reaper wire-server webapp account-pages team-settings smallstep-accomp ingress-nginx-controller nginx-ingress-services

# deploying sft and coturn services
deploy_calling_services

# print status of certs
kubectl get certificate
}