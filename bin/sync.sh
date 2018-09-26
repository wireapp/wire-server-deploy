#!/usr/bin/env bash

# Synchronize helm charts in git with the hosted version on S3.
# The contents of /charts are thus made available under
# https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
# To use the charts:
# helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
# helm search wire

# This script uses the helm s3 plugin,
# for more info see https://github.com/hypnoglow/helm-s3

# Usage: ./bin/sync.sh [--force]

set -e
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# At the time of writing, version 0.7.0 was installed. 
# Hopefully version locking isn't necessary
helm plugin list | grep "s3" > /dev/null || helm plugin install https://github.com/hypnoglow/helm-s3.git

helm s3 init s3://public.wire.com/charts

helm repo add wire s3://public.wire.com/charts 

charts=( wire-server fake-aws databases-ephemeral )
rm ./*.tgz &> /dev/null || true # clean any packaged files, if any
for chart in "${charts[@]}"; do
    "$SCRIPT_DIR/update.sh" "$chart"
    helm package "charts/${chart}" && sync
    tgz=$(ls "${chart}"-*.tgz)
    echo "syncing ${tgz}..."
    aws s3api head-object --bucket public.wire.com --key "charts/${tgz}" &> /dev/null
    remote=$?
    if [ $remote -ne 0 ]; then
        helm s3 push "$tgz" wire
        printf "\n--> pushed %s to S3\n\n" "$tgz"
    else
        if [[ $1 == *--force* ]]; then
            helm s3 push "$tgz" wire --force
            printf "\n--> (!) force pushed %s to S3\n\n" "$tgz"
        else
            printf "\n--> %s not changed or not version bumped; doing nothing.\n\n" "$chart"
        fi
    fi
    rm "$tgz"

done

helm s3 reindex wire
helm search wire


# TODO: improve the above script by exiting with an error if helm charts have changed but a version was not bumped.
# TODO: hash comparison won't work directly: helm package ... results in new md5 hashes each time, even if files don't change. This is due to files being ordered differently in the tar file. See https://github.com/helm/helm/issues/3264
# cur_hash=($(md5sum ${tgz}))
# echo $cur_hash
# remote_hash=$(aws s3api head-object --bucket public.wire.com --key charts/${tgz} | jq '.ETag' -r| tr -d '"')
# echo $remote_hash
# if [ "$cur_hash" != "$remote_hash" ]; then
#     echo "ERROR: Current hash should be the same as the remote hash. Please bump the version of chart {$chart}."
#     exit 1
# fi
