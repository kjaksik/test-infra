#!/usr/bin/env bash

###
# This script is designed to check the compatibility of the Kyma CLI with previous Kyma versions.
# It will calculate which Kyma version should be tested and will pass it on to the 'provision-vm-cli.sh' script
#
# INPUT:
# - COMPAT_BACKTRACK: number of versions to go back in Kyma
#
# REQUIREMENTS:
# - git
###

set -o errexit

VARIABLES=(
    COMPAT_BACKTRACK
)

#Exported variables
export KYMA_PROJECT_DIR=${KYMA_PROJECT_DIR:-"/home/prow/go/src/github.com/kyma-project"}
export TEST_INFRA_SOURCES_DIR="${KYMA_PROJECT_DIR}/test-infra"
export TEST_INFRA_SCRIPTS="${TEST_INFRA_SOURCES_DIR}/prow/scripts"

# shellcheck source=prow/scripts/lib/utils.sh
source "${TEST_INFRA_SOURCES_DIR}/prow/scripts/lib/utils.sh"
# shellcheck disable=SC1090
source "${TEST_INFRA_SCRIPTS}/library.sh"

utils::check_required_vars "${VARIABLES[@]}"

echo "--------------------------------------------------------------------------------"
echo "Kyma CLI compatibility checker"
echo "--------------------------------------------------------------------------------"

# Get all release tags (RC included)
RELEASES=$(curl -s https://api.github.com/repos/kyma-project/kyma/releases | grep -P '(tag_name": ")(\d+\.\d+\.\d+.*\",?$)' | awk '{print $2}')

# Clean up spaces, quotes and RC suffix
RELEASES=${RELEASES//[,\"]}
RELEASES=${RELEASES//\-rc[0-9]}

# Split into array
RELEASES=(${RELEASES})

# Remove duplicates
RELEASES=($(printf "%s\n" "${RELEASES[@]}" | uniq))

# Go through releases ignoring patch versions in descending order until we skip the desired number of minor releases

# remove patch
CURRENT=$(echo "${RELEASES[0]}" | awk -F'.' '{print $1"."$2}')
for r in "${RELEASES[@]}"; do
    # remove patch from candidate
    WANT=$(echo "${r}" | awk -F'.' '{print $1"."$2}')

    if [[ "$WANT" != "$CURRENT" ]]; then
        # check if we need to backtrack more
        if [[ $COMPAT_BACKTRACK == 1 ]]; then
            # Found the target release
            TARGET=$r
            break
        else
            # Still need to backtrack further
            COMPAT_BACKTRACK=$((COMPAT_BACKTRACK - 1))
            CURRENT=$(echo "${r}" | awk -F'.' '{print $1"."$2}')
        fi
    fi
done

# Exceptional release replacements. Add a replacement pair here as follows: "release::replacement"
# This is required when we have special releases that do not follow the regular pattern.
EXCEPTIONS=('1.16.0::1.16.0-rc3')

for index in "${EXCEPTIONS[@]}" ; do
    KEY="${index%%::*}"
    VALUE="${index##*::}"
    if [[ "${TARGET}" == "${KEY}" ]]; then
        TARGET="${VALUE}"
        break
    fi
done

shout "Checking Kyma CLI compatibility with Kyma ${TARGET}"
date

# Call CLI integration script with the target release
"${TEST_INFRA_SCRIPTS}"/provision-vm-cli.sh --kyma-version "${TARGET}"