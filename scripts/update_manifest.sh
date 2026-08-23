#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

. "${ROOT_DIR}/config.sh"
. "${ROOT_DIR}/${PRODUCT}/config.sh"

cd "${ROOT_DIR}/repos/opensearch-build"

# # check for uncommitted changes
# if ! git diff --quiet || ! git diff --cached --quiet; then
#     echo "ERROR: uncommitted changes in opensearch-build"
#     exit 1
# fi

# use separate branches for opensearch and dashboards
if [[ "$PRODUCT" == "opensearch-dashboards" ]]; then
    BRANCH="${PREFIX}-dashboards-${VERSION}"
else
    BRANCH="${PREFIX}-${VERSION}"
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git checkout "$BRANCH"
else
    git checkout -b "$BRANCH"
fi

MANIFEST="${ROOT_DIR}/repos/opensearch-build/manifests/${VERSION}/${PRODUCT}-${VERSION}.yml"

if grep -q "github\.com/opensearch-project" "$MANIFEST"; then
    python3 "${ROOT_DIR}/scripts/lp_manifest.py" "$PRODUCT" "$VERSION" "$PREFIX" "$LP_PUBLIC_REMOTE"
    git add "$MANIFEST"
    git commit -m "Update manifest for ${PRODUCT} ${VERSION}"
fi
