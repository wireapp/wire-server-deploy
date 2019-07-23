#!/usr/bin/env bash

NAMESPACE=${NAMESPACE:-monitoring}

help repo update

helm upgrade --install --namespace "$NAMESPACE" "$NAMESPACE-elasticsearch-ephemeral" wire/elasticsearch-ephemeral
helm upgrade --install --namespace "$NAMESPACE" "$NAMESPACE-fluent-bit" wire/fluent-bit
helm upgrade --install --namespace "$NAMESPACE" "$NAMESPACE-kibana" wire/kibana
helm upgrade --install --namespace "$NAMESPACE" "$NAMESPACE-elasticsearch-curator" wire/elasticsearch-curator
