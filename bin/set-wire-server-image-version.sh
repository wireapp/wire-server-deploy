#!/usr/bin/env bash


USAGE="$0 <target-backend-version>"
target_version=${1?$USAGE}

charts=(brig cannon galley gundeck spar cargohold proxy cassandra-migrations) 

for chart in "${charts[@]}"; do
    sed -i "s/  tag: .*/  tag: $target_version/g" "charts/$chart/values.yaml"
done

#special case nginz
sed -i "s/   tag: [0-9].*/   tag: $target_version/g" "charts/nginz/values.yaml"
