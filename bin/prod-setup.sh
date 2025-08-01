#!/usr/bin/env bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."

secretsfilename=${secretsfilename:-secrets.yaml}
valuesfilename=${valuesfilename:-values.yaml}

echo $secretsfilename
echo $valuesfilename

NAMESPACE=${NAMESPACE:-prod}

set -ex

echo "NAMESPACE = $NAMESPACE"

function install_chart() {
    local chart;
    chart=$1
    external=$2
    version=$3
    timeout=${4:-300}
    if [[ $external == 'external' ]]; then
        location="wire/${chart}"
    else
        location="${DIR}/helm_charts/${chart}"
        helmDepUp "$location"
    fi
    if [ -n "$version" ]; then
        version="--version $version"
        echo "Instaling version $version"
    fi
    valuesfile="${DIR}/values/${chart}/$valuesfilename"
    secretsfile="${DIR}/values/${chart}/$secretsfilename"
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
helm repo add cos https://centerforopenscience.github.io/helm-charts/
helm repo add goog https://kubernetes-charts-incubator.storage.googleapis.com
helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts || true

# Install external charts first
install_chart cassandra-external external
install_chart minio-external external
install_chart elasticsearch-external external
install_chart databases-ephemeral external
install_chart fake-aws external
install_chart smtp external
install_chart wire-server external
install_chart nginx-lb-ingress external
