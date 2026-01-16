
#!/usr/bin/env bash
# shellcheck disable=SC2087
set -Eeo pipefail

# Read values from environment variables with defaults
BASE_DIR="/wire-server-deploy"
TARGET_SYSTEM="example.dev"
CERT_MASTER_EMAIL="certmaster@${TARGET_SYSTEM}"

# this IP should match the DNS A record value for TARGET_SYSTEM
# assuming it to be the public address used by clients to reach public Address 
HOST_IP=""
if [ -z "$HOST_IP" ]; then 
HOST_IP=$(wget -qO- https://api.ipify.org)
fi

# picking a node for calling traffic
CALLING_NODE="kubenode3"

# Creates values.yaml from prod-values.example.yaml and secrets.yaml from prod-secrets.example.yaml
# Works on all chart directories in $BASE_DIR/values/
process_values() {

  ENV=$1
  TYPE=$2
  charts=(fake-aws smtp rabbitmq databases-ephemeral reaper wire-server webapp account-pages team-settings smallstep-accomp ingress-nginx-controller nginx-ingress-services)

  if [[ "$ENV" != "prod" ]] || [[ -z "$TYPE" ]] ; then
    echo "Error: This function only supports prod deployments with TYPE as values or secrets. ENV must be 'prod', got: '$ENV' and '$TYPE'"
    exit 1
  fi
  timestp=$(date +"%Y%m%d_%H%M%S")

  for chart in "${charts[@]}"; do
    chart_dir="$BASE_DIR/values/$chart"
    if [[ -d "$chart_dir" ]]; then
      if [[ -f "$chart_dir/${ENV}-${TYPE}.example.yaml" ]]; then
        if [[ ! -f "$chart_dir/${TYPE}.yaml" ]]; then
          cp "$chart_dir/${ENV}-${TYPE}.example.yaml" "$chart_dir/${TYPE}.yaml"
          echo "Used template ${ENV}-${TYPE}.example.yaml to create $chart_dir/${TYPE}.yaml"
        else
          echo "$chart_dir/${TYPE}.yaml already exists, archiving it and creating a new one."
          mv "$chart_dir/${TYPE}.yaml" "$chart_dir/${TYPE}.yaml.bak.$timestp"
          cp "$chart_dir/${ENV}-${TYPE}.example.yaml" "$chart_dir/${TYPE}.yaml"
        fi
      fi
    fi
  done
}

# selectively setting values of following charts which requires additional values
# wire-server, webapp, team-settings, account-pages, nginx-ingress-services, sftd and coturn
configure_values() {

  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf $TEMP_DIR' EXIT

  # to find IP address of calling NODE
  CALLING_NODE_IP=$(kubectl get node "$CALLING_NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

  # Fixing the hosts with TARGET_SYSTEM and setting the turn server
  sed -e "s/example.com/$TARGET_SYSTEM/g" \
      "$BASE_DIR/values/wire-server/values.yaml" > "$TEMP_DIR/wire-server-values.yaml"

  # fixing the turnStatic values
  yq eval -i ".brig.turnStatic.v2 = [\"turn:$HOST_IP:3478\", \"turn:$HOST_IP:3478?transport=tcp\"]" "$TEMP_DIR/wire-server-values.yaml"

  # Fixing the hosts in webapp team-settings and account-pages charts
  for chart in webapp team-settings account-pages; do
    sed "s/example.com/$TARGET_SYSTEM/g" "$BASE_DIR/values/$chart/values.yaml" > "$TEMP_DIR/$chart-values.yaml"
  done

  # Setting certManager and DNS records
  sed -e 's/useCertManager: false/useCertManager: true/g' \
    -e "/certmasterEmail:$/s/certmasterEmail:/certmasterEmail: $CERT_MASTER_EMAIL/" \
    -e "s/example.com/$TARGET_SYSTEM/" \
    "$BASE_DIR/values/nginx-ingress-services/values.yaml" > "$TEMP_DIR/nginx-ingress-services-values.yaml"

  # Fixing SFTD hosts and setting the cert-manager to http01
  sed -e "s/webapp.example.com/webapp.$TARGET_SYSTEM/" \
      -e "s/sftd.example.com/sftd.$TARGET_SYSTEM/" \
      -e 's/name: letsencrypt-prod/name: letsencrypt-http01/' \
      "$BASE_DIR/values/sftd/values.yaml" > "$TEMP_DIR/sftd-values.yaml"

  # Setting coturn node IP values
  yq eval -i ".coturnTurnListenIP = \"$CALLING_NODE_IP\"" "$BASE_DIR/values/coturn/values.yaml"
  yq eval -i ".coturnTurnRelayIP = \"$CALLING_NODE_IP\"" "$BASE_DIR/values/coturn/values.yaml"
  yq eval -i ".coturnTurnExternalIP = \"$HOST_IP\"" "$BASE_DIR/values/coturn/values.yaml"

  # Compare and copy files if different
  for file in wire-server-values.yaml webapp-values.yaml team-settings-values.yaml account-pages-values.yaml \
              nginx-ingress-services-values.yaml sftd-values.yaml; do
    if ! cmp -s "$TEMP_DIR/$file" "$BASE_DIR/values/${file%-values.yaml}/values.yaml"; then
      cp "$TEMP_DIR/$file" "$BASE_DIR/values/${file%-values.yaml}/values.yaml"
      echo "Updating  $BASE_DIR/values/${file%-values.yaml}/values.yaml"
    fi
  done

}

deploy_charts() {

  local charts=("$@")
  echo "Following charts will be deployed: ${charts[*]}"

  for chart in "${charts[@]}"; do
    chart_dir="$BASE_DIR/charts/$chart"
    values_file="$BASE_DIR/values/$chart/values.yaml"
    secrets_file="$BASE_DIR/values/$chart/secrets.yaml"

    if [[ ! -d "$chart_dir" ]]; then
      echo "Error: Chart directory $chart_dir does not exist. Exiting fix the charts"
      exit 1
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

    # handle wire-server to inject PostgreSQL password from databases-ephemeral
    if [[ "$chart" == "wire-server" ]]; then

      echo "Retrieving PostgreSQL password from databases-ephemeral for wire-server deployment..."
      if kubectl get secret wire-postgresql-secret &>/dev/null; then
      # Usage: sync-k8s-secret-to-wire-secrets.sh <secret-name> <secret-key> <yaml-file> <yaml-path's>
         "$BASE_DIR/bin/sync-k8s-secret-to-wire-secrets.sh" \
          wire-postgresql-secret password \
          "$BASE_DIR/values/wire-server/secrets.yaml" \
          .brig.secrets.pgPassword .galley.secrets.pgPassword
      else
        echo "⚠️  Warning: PostgreSQL secret 'wire-postgresql-secret' not found, skipping secret sync"
        echo "    Make sure databases-ephemeral chart is deployed before wire-server"
      fi
    fi

    echo "Deploying $chart as $helm_command"
    eval "$helm_command"
  done

  # display running pods post deploying all helm charts in default namespace
  kubectl get pods --sort-by=.metadata.creationTimestamp
}

deploy_cert_manager() {

  kubectl get namespace cert-manager-ns || kubectl create namespace cert-manager-ns
  helm upgrade --install -n cert-manager-ns cert-manager  "$BASE_DIR/charts/cert-manager" --values "$BASE_DIR/values/cert-manager/values.yaml"

  # display running pods
  kubectl get pods --sort-by=.metadata.creationTimestamp -n cert-manager-ns
}

deploy_calling_services() {

  echo "Deploying sftd and coturn"
  # select the node to deploy sftd
  kubectl annotate node "$CALLING_NODE" wire.com/external-ip="$HOST_IP" --overwrite
  helm upgrade --install sftd "$BASE_DIR/charts/sftd" --set "nodeSelector.kubernetes\\.io/hostname=$CALLING_NODE" --values  "$BASE_DIR/values/sftd/values.yaml"

  kubectl annotate node "$CALLING_NODE" wire.com/external-ip="$HOST_IP" --overwrite
  helm upgrade --install coturn "$BASE_DIR/charts/coturn" --set "nodeSelector.kubernetes\\.io/hostname=$CALLING_NODE" --values "$BASE_DIR/values/coturn/values.yaml" --values "$BASE_DIR/values/coturn/secrets.yaml"
}

main() {
# Create prod-values.example.yaml to values.yaml and take backup
process_values "prod" "values"
# Create prod-secrets.example.yaml to secrets.yaml and take backup
process_values "prod" "secrets"

# configure chart specific variables for each chart in values.yaml file
configure_values

# deploying with external datastores, useful for prod setup
deploy_charts cassandra-external elasticsearch-external minio-external fake-aws smtp rabbitmq databases-ephemeral reaper wire-server webapp account-pages team-settings smallstep-accomp ingress-nginx-controller nginx-ingress-services

# deploying cert manager to issue certs, by default letsencrypt-http01 issuer is configured
deploy_cert_manager

# deploying sft and coturn services
# not implemented yet
deploy_calling_services

# print status of certs
kubectl get certificate
}

main
