#!/usr/bin/env bash

NAMESPACE=${NAMESPACE:-prod}

function kill_all_cannons() {
    echo "Killing all cannons"
    while IFS= read -r cannon
    do
        echo "Killing $cannon"
        kubectl -n "$NAMESPACE" delete pod "$cannon"
    done < <(kubectl -n "$NAMESPACE" get pods | grep -e "cannon" | awk '{ print $1 }')
}

while true
do
    FIRST_POD=$(kubectl -n "$NAMESPACE" get pods --sort-by=.metadata.creationTimestamp | grep -e "cannon" -e "redis-ephemeral" | head -n 1 | awk '{ print $1 }')

    if [[ "$FIRST_POD" =~ "redis-ephemeral" ]];
        then echo "redis-ephemeral is the oldest pod, all good"
        else kill_all_cannons
    fi
    echo 'Sleeping 1 seconds'
    sleep 1
done
