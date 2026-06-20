#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"
PRODUCT_DIR="${ROOT_DIR}/${PRODUCT}"
REPO_BASE="${PRODUCT_DIR}/repos"
. "${PRODUCT_DIR}/config.sh"
. "${PRODUCT_DIR}/patches.sh"

BRANCH="${PREFIX}-${VERSION}"

for dir in "$REPO_BASE"/*; do
    [[ -d "$dir" ]] || continue
    cd "$dir"
    repo=$(basename "$dir")

    git checkout "$BRANCH" 2>/dev/null || { echo "ERROR: $repo has no $BRANCH branch"; exit 1; }

    echo
    echo "$repo"

    apply_patches "$repo"

    lp_tag=$(git tag -l "${PREFIX}-v${VERSION}*" | head -1)
    [[ -n "$lp_tag" ]] || { echo "ERROR: no ${PREFIX}-v${VERSION}* tag found"; exit 1; }
    git tag -f "$lp_tag" -m "$lp_tag"
done
