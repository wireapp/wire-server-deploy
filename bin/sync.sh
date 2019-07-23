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

USAGE="Sync helm charts to S3. Usage: $0 to sync all charts or $0 <chartname> to sync only a single one. --force-push can be used to override S3 artifacts. --reindex can be used to force a complete reindexing in case the index is malformed."
echo "$USAGE"
chart_name=$1

charts=(
    $(find $SCRIPT_DIR/../charts/ -maxdepth 1 -type d | sed -n "s=$SCRIPT_DIR/../charts/\(.\+\)=\1 =p")
)

if [ -n "$chart_name" ] && [ -d "$SCRIPT_DIR/../charts/$chart_name" ]; then
    echo "only syncing $chart_name"
    charts=( "$chart_name" )
fi

# install s3 plugin
# See https://github.com/hypnoglow/helm-s3/pull/56 for reason to use fork
s3_plugin_version=$(helm plugin list | grep "^s3 " | awk '{print $2}' || true)
if [[ $s3_plugin_version != "0.9.0" ]]; then
    echo "not version 0.9.0 from steven-sheehy fork, upgrading or installing plugin..."
    helm plugin remove s3 || true
    helm plugin install https://github.com/steven-sheehy/helm-s3.git --version v0.9.0
else
    # double check we have the right version of the s3 plugin
    plugin_sha=$(cat $HOME/.helm/plugins/helm-s3.git/.git/HEAD)
    if [[ $plugin_sha != "f7ab4a8818f11380807da45a6c738faf98106d62" ]]; then
        echo "git hash doesn't match forked s3-plugin version (or maybe there is a path issue and your plugins are installed elsewhere? Attempting to re-install..."
        helm plugin remove s3
        helm plugin install https://github.com/steven-sheehy/helm-s3.git --version v0.9.0
    fi
fi

# index/sync charts to S3
export AWS_REGION=eu-west-1
PUBLIC_DIR="charts"

S3_URL="s3://public.wire.com/$PUBLIC_DIR"
PUBLIC_URL="https://s3-eu-west-1.amazonaws.com/public.wire.com/$PUBLIC_DIR"

# initialize index file only if file doesn't yet exist
if ! aws s3api head-object --bucket public.wire.com --key "$PUBLIC_DIR/index.yaml" &> /dev/null ; then
    echo "initializing fresh index.yaml"
    helm s3 init "$S3_URL" --publish "$PUBLIC_URL"
fi

helm repo add "$PUBLIC_DIR" "$S3_URL"
helm repo add wire "$PUBLIC_URL"

rm ./*.tgz &> /dev/null || true # clean any packaged files, if any
for chart in "${charts[@]}"; do
    echo "Syncing chart $chart..."
    "$SCRIPT_DIR/update.sh" "$chart"
    helm package "charts/${chart}" && sync
    tgz=$(ls "${chart}"-*.tgz)
    echo "syncing ${tgz}..."
    # Push the artifact only if it doesn't already exist
    if ! aws s3api head-object --bucket public.wire.com --key "$PUBLIC_DIR/${tgz}" &> /dev/null ; then
        helm s3 push "$tgz" "$PUBLIC_DIR"
        printf "\n--> pushed %s to S3\n\n" "$tgz"
    else
        if [[ $1 == *--force-push* || $2 == *--force-push* || $3 == *--force-push* ]]; then
            helm s3 push "$tgz" "$PUBLIC_DIR" --force
            printf "\n--> (!) force pushed %s to S3\n\n" "$tgz"
        else
            printf "\n--> %s not changed or not version bumped; doing nothing.\n\n" "$chart"
        fi
    fi
    rm "$tgz"

done

if [[ $1 == *--reindex* || $2 == *--reindex* || $3 == *--reindex* ]]; then
    printf "\n--> (!) Reindexing, this can take a few minutes...\n\n"
    helm s3 reindex "$PUBLIC_DIR" --publish "$PUBLIC_URL"
    # see all results
    helm search wire/ -l
else
    printf "\n--> Not reindexing by default. Pass the --reindex flag in case the index.yaml is incomplete. See all wire charts using \n helm search wire -l\n\n"
fi


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
