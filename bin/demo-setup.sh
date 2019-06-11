#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."

display_usage() {
    echo "Usage: setup -o -b -s"
    echo "  -o   (--override--values) default values/secrets (i.e., looks for secrets.override.yaml and values.override.yaml)"
    echo "  -b   (--no-load-balancer) use this if you do not want to install a load balancer on the cluster (useful for cloud installations that have their own LB's)"
    echo "  -s   (--skip-dependency-update) do not update any helm chart dependencies (can be useful for reruns)"
    exit 1
}

secretsfilename="demo-secrets.example.yaml"
valuesfilename="demo-values.example.yaml"
installloadbalancer=true
updatedependencies=true

while getopts ":obs" opt; do
  case $opt in
    o)
      secretsfilename="demo-secrets.override.yaml"
      valuesfilename="demo-values.override.yaml"
      ;;
    b)
      installloadbalancer=false
      ;;
    s)
      updatedependencies=false
      ;;
  esac
done

echo "######################################################"
echo "Secrets: $secretsfilename"
echo "Values: $valuesfilename"
echo "Install loadbalancer on the cluster: $installloadbalancer"
echo "Update dependencies: $updatedependencies"
echo "######################################################"

NAMESPACE=${NAMESPACE:-demo}

set -ex

echo "NAMESPACE = $NAMESPACE"

phase_0_charts_metallb=( metallb )
phase_1_charts_pre=( fake-aws databases-ephemeral demo-smtp )
phase_2_charts_main=( wire-server )
# charts for ingress, creating ELB's and DNS records
phase_3_charts_ingress=( nginx-lb-ingress )
all_charts=( "${phase_0_charts_metallb[@]}" "${phase_1_charts_pre[@]}" "${phase_2_charts_main[@]}" "${phase_3_charts_ingress[@]}")

if [ "$updatedependencies" == true ] ; then
    # remove previous versions of helm charts, if any
    ( find "$DIR/charts" | grep ".tgz" | xargs -n 1 rm ) || true  # fails the first time we run this.

    # download/refresh dependencies, if any
    helm repo add cos https://centerforopenscience.github.io/helm-charts/
    helm repo add goog https://kubernetes-charts-incubator.storage.googleapis.com
    helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts || true

    for chart in "${all_charts[@]}"; do
        source "$DIR/bin/update.sh" "${chart}"
    done
fi

if [ "$installloadbalancer" == true ] ; then
    # Note that we should have a single metal lb in the whole cluster!
    helm upgrade --install --namespace metallb-system metallb \
        "${DIR}/charts/metallb" -f "${DIR}/values/metallb/${valuesfilename}" \
        --wait --timeout 1800
fi

for chart in "${phase_1_charts_pre[@]}"; do
    valuesfile="${DIR}/values/${chart}/${valuesfilename}"
    if [ -f "$valuesfile" ]; then
        helm upgrade --install --namespace "${NAMESPACE}" "${NAMESPACE}-${chart}" "${DIR}/charts/${chart}" \
            -f "$valuesfile" \
            --wait --timeout 1800
    else
        helm upgrade --install --namespace "${NAMESPACE}" "${NAMESPACE}-${chart}" "${DIR}/charts/${chart}" \
            --wait --timeout 1800
    fi
done

echo "Installing wire-server, this may take a long time, and take a long time before reporting errors. (timeout of $timeout seconds.) You may check for potential problems with 'kubectl -n $NAMESPACE get pods -w' or 'kubectl -n $NAMESPACE get all' and look for errors/pending."
for chart in "${phase_2_charts_main[@]}"; do
    valuesfile="${DIR}/values/${chart}/${valuesfilename}"
    secretsfile="${DIR}/values/${chart}/${secretsfilename}"
    if [ -f "$secretsfile" ]; then
        helm upgrade --install --namespace "${NAMESPACE}" "${NAMESPACE}-${chart}" "${DIR}/charts/${chart}" \
            -f "$valuesfile" \
            -f "$secretsfile" \
            --wait --timeout 900
    else
        helm upgrade --install --namespace "${NAMESPACE}" "${NAMESPACE}-${chart}" "${DIR}/charts/${chart}" \
            -f "$valuesfile" \
            --wait --timeout 900
    fi
done

# This expects ${DIR}/values/$NAMESPACE/${chart}/${secretsfile} to point to a file with plain text values for
# the tls wildcard certifcate and key. If you plan to use sops and encrypt the secrets, please ensure to use helm-wrapper
for chart in "${phase_3_charts_ingress[@]}"; do
    helm upgrade --install --namespace "${NAMESPACE}" "${NAMESPACE}-${chart}" "${DIR}/charts/${chart}" \
    -f "${DIR}/values/${chart}/${valuesfilename}" \
    -f "${DIR}/values/${chart}/${secretsfilename}" \
      --wait --timeout 300
done
