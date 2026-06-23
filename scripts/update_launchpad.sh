#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"

cd "${ROOT_DIR}/opensearch-build"

# check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: uncommitted changes in opensearch-build"
    exit 1
fi

# switch to product-specific branch
if [[ "$PRODUCT" == "opensearch-dashboards" ]]; then
    git checkout -B "${PREFIX}-dashboards-${VERSION}"
    git checkout "origin/lp-dashboards-${LAST_VERSION}" -- .launchpad.yaml 2>/dev/null || { echo "ERROR: no lp-dashboards-${LAST_VERSION} branch found"; exit 1; }
else
    git checkout -B "${PREFIX}-${VERSION}"
fi

cd "${ROOT_DIR}"

LAUNCHPAD_YAML="${ROOT_DIR}/opensearch-build/.launchpad.yaml"
ARTIFACTORY_URL="${ARTIFACTORY_URL:-https://canonical.jfrog.io/artifactory/dataplatform-opensearch-staging}"
PATCH_NUMBER="${PATCH_NUMBER:-0}"

sed -i.tmp "s|OPENSEARCH_VERSION:.*|OPENSEARCH_VERSION: ${VERSION}|g" "$LAUNCHPAD_YAML"
sed -i.tmp "s|OPENSEARCH_DASHBOARDS_VERSION:.*|OPENSEARCH_DASHBOARDS_VERSION: ${VERSION}|g" "$LAUNCHPAD_YAML"
sed -i.tmp "s|PATCH_NUMBER:.*|PATCH_NUMBER: ${PATCH_NUMBER}|g" "$LAUNCHPAD_YAML"
sed -i.tmp "s|ARTIFACTORY_URL:.*|ARTIFACTORY_URL: ${ARTIFACTORY_URL}|g" "$LAUNCHPAD_YAML"

rm -f "${LAUNCHPAD_YAML}.tmp"

cd "${ROOT_DIR}/opensearch-build"
git add .launchpad.yaml
git diff --cached --quiet || git commit -m "Update .launchpad.yaml"
