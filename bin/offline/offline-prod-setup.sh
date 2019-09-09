#!/usr/bin/env bash

# Similar script to prod-setup.sh
# This script can be used in an environment without access to public helm repositories

set -e

TOP_LEVEL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

secretsfilename="secrets.yaml"
valuesfilename="values.yaml"

echo $secretsfilename
echo $valuesfilename

NAMESPACE=${NAMESPACE:-default}

set -ex

echo "NAMESPACE = $NAMESPACE"

rebuild=${1:-true}
online=${2:-false}

$online && echo "online-mode: be sure to have internet!"
$online && sleep 3

function install_chart() {
    local chart;
    chart=$1
    external=$2
    version=$3
    timeout=${4:-900}
    if [[ $external == 'external' ]]; then
        location="wire/${chart}"
    else
        location="${TOP_LEVEL_DIR}/charts/${chart}"
        $rebuild && (cd $location && helm dep build)
        $online && "${TOP_LEVEL_DIR}/bin/update.sh" "$chart"
    fi
    if [ -n "$version" ]; then
        version="--version $version"
        echo "Instaling version $version"
    fi
    valuesfile="${TOP_LEVEL_DIR}/values/${chart}/$valuesfilename"
    secretsfile="${TOP_LEVEL_DIR}/values/${chart}/$secretsfilename"
    if [[ -f "$valuesfile" && -f "$secretsfile" ]]; then
        option="-f $valuesfile -f $secretsfile"
    elif [[ -f "$valuesfile" ]]; then
        option="-f $valuesfile"
    else
        option=""
    fi

    helm upgrade --install --namespace "${NAMESPACE}" "${NAMESPACE}-${chart}" "${location}" \
        $option \
        $version \
        --wait --timeout "$timeout"

}

# download/refresh dependencies, if any
$online && helm repo add cos https://centerforopenscience.github.io/helm-charts/ || true
$online && helm repo add goog https://kubernetes-charts-incubator.storage.googleapis.com || true
$online && helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts || true
$online && helm repo add stable	https://kubernetes-charts.storage.googleapis.com || true

helm repo remove local || true
$online || helm repo remove cos || true
$online || helm repo remove goog || true
$online || helm repo remove wire || true
$online || helm repo remove stable || true

install_chart cassandra-external LOKAL
install_chart minio-external LOKAL
install_chart elasticsearch-external LOKAL
install_chart databases-ephemeral LOKAL
install_chart fake-aws LOKAL
install_chart wire-server LOKAL
install_chart reaper LOKAL
install_chart nginx-lb-ingress LOKAL
