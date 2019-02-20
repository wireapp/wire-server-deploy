#!/usr/bin/env bash

set -e

USAGE="Bump chart version for chart and subcharts (if any). Usage: $0 <chartname>"
chart=${1:?$USAGE}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CHART_DIR="$( cd "$SCRIPT_DIR/../charts" && pwd )"

if [ ! -d "$CHART_DIR/$chart" ]; then
    echo "chart $chart does not exist."
    exit 1
fi


old_version=$(grep version "$CHART_DIR/$chart/Chart.yaml" | awk -F ':' '{print $2}')

# bump patch (-p) by default.
new_version=$("$SCRIPT_DIR/increment_version.sh" -p "$old_version")

"$SCRIPT_DIR/set-version.sh" "$chart" "$new_version"
echo "$new_version"
