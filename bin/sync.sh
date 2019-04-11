#!/usr/bin/env bash

# Synchronize helm charts in git with the hosted version on S3.
# The contents of /charts are thus made available under
# https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
# To use the charts:
# helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
# helm search wire

# This script uses the helm s3 plugin,
# for more info see https://github.com/hypnoglow/helm-s3

set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

USAGE="Sync helm charts to S3. Usage: $0 to sync all charts or $0 <chartname> to sync only a single one. --force-push can be used to override S3 artifacts."
echo "$USAGE"
chart_name=$1

# TODO: Should subcharts also be exposed directly? If not, this list needs to be kept up-to-date
charts=(
    wire-server
    wire-server-metrics
    fake-aws
    databases-ephemeral
    redis-ephemeral
    metallb
    nginx-lb-ingress
    demo-smtp
    cassandra-external
    minio-external
    elasticsearch-external
    aws-ingress
)

if [ -n "$chart_name" ] && [ -d "$SCRIPT_DIR/../charts/$chart_name" ]; then
    echo "only syncing $chart_name"
    charts=( "$chart_name" )
fi

# install s3 plugin
# At the time of writing, version 0.7.0 was installed.
# Hopefully version locking isn't necessary
helm plugin list | grep "s3" > /dev/null || helm plugin install https://github.com/hypnoglow/helm-s3.git

# Note: on providing a public URL for charts synced to S3
# * This is not yet supported by helm-s3 plugin until
#   https://github.com/hypnoglow/helm-s3/pull/56 is implemented
# * This workaround uses two folders on s3;
#   - one to sync with helm-s3,
#   - a second one with a manually-changed index.yaml to allow fetching charts from public URLs

INDEX_S3_DIR="charts-tmp"
PUBLIC_DIR="charts"
workaround_issue_helm_s3_56() {
    # retrieve index
    aws s3 cp s3://public.wire.com/$INDEX_S3_DIR/index.yaml index.yaml

    # sync from $INDEX_S3_DIR to charts directory
    if [ -n "$chart_name" ]; then
        # Read chart urls into a bash array
        # mapfile/readarray are nicer, but don't work on Mac's builtin bash
        urls=()
        while IFS='' read -r line; do array+=("$line"); done < <(yq r index.yaml 'entries.*.*.urls.0' | awk -F '- ' '{print $2$3}' | grep "$chart_name")
    else
        urls=()
        while IFS='' read -r line; do array+=("$line"); done < <(yq r index.yaml 'entries.*.*.urls.0' | awk -F '- ' '{print $2$3}')
    fi
    for url in "${urls[@]}"; do
        newurl=${url/$INDEX_S3_DIR/$PUBLIC_DIR};
        echo "old=$url and new=$newurl"
        aws s3 cp "$url" "$newurl"
    done

    # update and upload index to charts
    sed -i'.bak' -e 's/s3\:\/\//https\:\/\/s3-eu-west-1.amazonaws.com\//g' index.yaml
    aws s3 cp index.yaml s3://public.wire.com/$PUBLIC_DIR/index.yaml
}

# index/sync charts to S3
export AWS_REGION=eu-west-1

helm s3 init "s3://public.wire.com/$INDEX_S3_DIR"
helm repo add "$INDEX_S3_DIR" "s3://public.wire.com/$INDEX_S3_DIR"

rm ./*.tgz &> /dev/null || true # clean any packaged files, if any
for chart in "${charts[@]}"; do
    "$SCRIPT_DIR/update.sh" "$chart"
    helm package "charts/${chart}" && sync
    tgz=$(ls "${chart}"-*.tgz)
    echo "syncing ${tgz}..."
    # Push the artifact only if it doesn't already exist
    if ! aws s3api head-object --bucket public.wire.com --key "$INDEX_S3_DIR/${tgz}" &> /dev/null ; then
        helm s3 push "$tgz" "$INDEX_S3_DIR"
        printf "\n--> pushed %s to S3\n\n" "$tgz"
    else
        if [[ $1 == *--force-push* || $2 == *--force-push* ]]; then
            helm s3 push "$tgz" "$INDEX_S3_DIR" --force
            printf "\n--> (!) force pushed %s to S3\n\n" "$tgz"
        else
            printf "\n--> %s not changed or not version bumped; doing nothing.\n\n" "$chart"
        fi
    fi
    rm "$tgz"

done

helm s3 reindex "$INDEX_S3_DIR"

workaround_issue_helm_s3_56

# see results
helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
helm search wire/

# TODO: improve the above script by exiting with an error if helm charts have changed but a version was not bumped.
# TODO: hash comparison won't work directly: helm package ... results in new md5 hashes each time, even if files don't change. This is due to files being ordered differently in the tar file. See
# * https://github.com/helm/helm/issues/3264
# * https://github.com/helm/helm/issues/3612
# cur_hash=($(md5sum ${tgz}))
# echo $cur_hash
# remote_hash=$(aws s3api head-object --bucket public.wire.com --key charts/${tgz} | jq '.ETag' -r| tr -d '"')
# echo $remote_hash
# if [ "$cur_hash" != "$remote_hash" ]; then
#     echo "ERROR: Current hash should be the same as the remote hash. Please bump the version of chart {$chart}."
#     exit 1
# fi
