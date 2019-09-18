#!/usr/bin/env bash

USAGE="Write version to chart and subcharts (if any). Usage: $0 <chartname> <semantic version>"
chart=${1:?$USAGE}
version=${2:?$USAGE}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CHART_DIR="$( cd "$SCRIPT_DIR/../charts" && pwd )"
tempfile=$(mktemp)

# (sed usage should be portable for both GNU sed and BSD (Mac OS) sed)

function update_chart(){
    chart_file=$1
    sed -e "s/version: .*/version: $target_version/g" "$chart_file" > "$tempfile" && mv "$tempfile" "$chart_file"
}

function write_versions() {
    target_version=$1

    # update chart version
    update_chart Chart.yaml

    # update all dependencies, if any
    if [ -a requirements.yaml ]; then
        sed -e "s/  version: \".*\"/  version: \"$target_version\"/g" requirements.yaml > "$tempfile" && mv "$tempfile" requirements.yaml
        deps=( $(helm dependency list | grep -v NAME | awk '{print $1}') )
        for dep in "${deps[@]}"; do
            if [ -d "$CHART_DIR/$dep" ] && [ "$chart" != "$dep" ]; then
                (cd "$CHART_DIR/$dep" && write_versions "$target_version")
            fi
        done
    fi
}

cd "$CHART_DIR/$chart" && write_versions "$version"
