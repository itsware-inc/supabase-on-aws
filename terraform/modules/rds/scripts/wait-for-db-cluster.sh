#!/usr/bin/env bash

set -eo pipefail

function isDbClusterAvailableWithNoPendingModifiedValues() {
  local dbCluster

  dbCluster="$(
    aws rds describe-db-clusters \
      --region "$AWS_REGION" \
      --profile "$AWS_PROFILE" \
      --db-cluster-identifier "$CLUSTER_IDENTIFIER"
  )"

  jq -e '.DBClusters[0] | .Status == "available" and .PendingModifiedValues == null' > /dev/null <<< "$dbCluster"
}

printf 'Waiting for database cluster status to be "available" with no pending modified values\n'

while true; do
  isDbClusterAvailableWithNoPendingModifiedValues && break
  printf 'Database cluster is not ready yet\n'
  sleep 10
done
