#!/bin/bash

###
# Following script deprovisions GKE cluster.
#
# INPUTS:
# - GCLOUD_SERVICE_KEY_PATH - content of service account credentials json file
# - GCLOUD_PROJECT_NAME - name of GCP project
# - CLUSTER_NAME - name for the new cluster
# - GCLOUD_COMPUTE_ZONE - zone in which the new cluster will be deprovisioned
#
# REQUIREMENTS:
# - gcloud
###

set -o errexit

#Exported variables
export TEST_INFRA_SOURCES_DIR="${KYMA_PROJECT_DIR}/test-infra"

# shellcheck source=prow/scripts/lib/utils.sh
source "${TEST_INFRA_SOURCES_DIR}/prow/scripts/lib/utils.sh"

requiredVars=(
   GCLOUD_SERVICE_KEY_PATH
   GCLOUD_PROJECT_NAME
   CLUSTER_NAME
   GCLOUD_COMPUTE_ZONE
)

utils::check_required_vars "${requiredVars[@]}"

command -v gcloud

gcloud auth activate-service-account --key-file="${GCLOUD_SERVICE_KEY_PATH}"
gcloud config set project "${GCLOUD_PROJECT_NAME}"
gcloud config set compute/zone "${GCLOUD_COMPUTE_ZONE}"

declare -a GCLOUD_PARAMS

GCLOUD_PARAMS+=("${CLUSTER_NAME}")
GCLOUD_PARAMS+=("--quiet")

# Check if removing regionl cluster.
if [ "${PROVISION_REGIONAL_CLUSTER}" ] && [ "${CLOUDSDK_COMPUTE_REGION}" ]; then
  #Pass gke region name to delete command.
  GCLOUD_PARAMS+=("--region=${CLOUDSDK_COMPUTE_REGION}")
fi

if [ -z "${DISABLE_ASYNC_DEPROVISION+x}" ]; then
    GCLOUD_PARAMS+=("--async")
fi

echo -e "\n---> Deleting cluster with following parameters."
echo "${GCLOUD_PARAMS[@]}"
echo -e "\n---> Deleting cluster"

gcloud container clusters delete "${GCLOUD_PARAMS[@]}"
