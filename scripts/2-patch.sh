#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"
PRODUCT_DIR="${ROOT_DIR}/${PRODUCT}"
REPO_BASE="${ROOT_DIR}/repos/${PRODUCT}"
. "${PRODUCT_DIR}/config.sh"
. "${PRODUCT_DIR}/patches.sh"

BRANCH="${PREFIX}-${VERSION}"

for dir in "$REPO_BASE"/*; do
    [[ -d "$dir" ]] || continue
    cd "$dir"
    repo=$(basename "$dir")

    echo
    echo "$repo"

    # check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "ERROR: uncommitted changes in $repo"
        exit 1
    fi

    git show-ref --verify --quiet "refs/heads/$BRANCH" || { echo "ERROR: $repo has no $BRANCH branch"; exit 1; }
    git checkout "$BRANCH"

    apply_patches "$repo"

    lp_tag=$(git tag -l "${PREFIX}-v${VERSION}*" | head -1)
    [[ -n "$lp_tag" ]] || { echo "ERROR: no ${PREFIX}-v${VERSION}* tag found"; exit 1; }

    # only retag if tag doesn't exist or points to wrong commit
    if [[ $(git rev-parse "$lp_tag^{}") != $(git rev-parse HEAD) ]]; then
        git tag -f "$lp_tag" -m "$lp_tag"
    fi
done
