#!/usr/bin/env bash

USAGE="download and bundle dependent helm charts: $0 <chart-directory>"
chart=${1:?$USAGE}

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
CHARTS_DIR="$BASE_DIR/charts"

set -e

# remove previous bundled versions of helm charts, if any
find "$CHARTS_DIR" | grep ".tgz$" > /tmp/helm-old-files && cat /tmp/helm-old-files | xargs -n 1 rm

# nothing serves on localhost, remove that repo
helm repo remove local 2&> /dev/null || true

# hacky workaround for helm's lack of recursive dependency update
# See https://github.com/helm/helm/issues/2247
helmDepUp () {
    local path
    path=$1
    cd $path
    echo "Updating dependencies in $path ..."
    if [ -f requirements.yaml ]; then
      # very hacky bash, I'm sorry
      for subpath in $(cat requirements.yaml | grep "file://" | awk '{ print $2 }' | xargs -n 1 | cut -c 8-)
      do
        ( helmDepUp "$subpath" )
      done
    fi
    helm dep up
    echo "... updating in $path done."
}


helmDepUp "${CHARTS_DIR}/${chart}"
