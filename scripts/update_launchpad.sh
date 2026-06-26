#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"
. "${ROOT_DIR}/${PRODUCT}/config.sh"

PATCHES_DIR="${ROOT_DIR}/opensearch-build/patches"
LAUNCHPAD_YAML="${ROOT_DIR}/repos/opensearch-build/.launchpad.yaml"

cd "${ROOT_DIR}/repos/opensearch-build"

# check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: uncommitted changes in opensearch-build"
    exit 1
fi

# switch to product-specific branch
if [[ "$PRODUCT" == "opensearch-dashboards" ]]; then
    BRANCH="${PREFIX}-dashboards-${VERSION}"
    TEMPLATE="${PATCHES_DIR}/launchpad-dashboards.yaml.template"
else
    BRANCH="${PREFIX}-${VERSION}"
    TEMPLATE="${PATCHES_DIR}/launchpad.yaml.template"
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git checkout "$BRANCH"
else
    git checkout -b "$BRANCH"
fi

# copy .launchpad.yaml from template
sed "s/\${VERSION}/${VERSION}/g" "$TEMPLATE" > "$LAUNCHPAD_YAML"
sed -i.tmp "s|PATCH_NUMBER:.*|PATCH_NUMBER: ${PATCH_NUMBER}|g" "$LAUNCHPAD_YAML"
sed -i.tmp "s|ARTIFACTORY_URL:.*|ARTIFACTORY_URL: ${ARTIFACTORY_URL}|g" "$LAUNCHPAD_YAML"

if [[ "$PRODUCT" == "opensearch-dashboards" ]]; then
    case "$VERSION" in
        3.*) sed -i.tmp "s|channel: 18/stable|channel: 20/stable|" "$LAUNCHPAD_YAML" ;;
    esac
fi

rm -f "${LAUNCHPAD_YAML}.tmp"

git add .launchpad.yaml
git diff --cached --quiet || git commit -m "Update .launchpad.yaml for ${PRODUCT}"
