#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOS_DIR="${ROOT_DIR}/repos/${PRODUCT}"

. "${ROOT_DIR}/config.sh"
. "${ROOT_DIR}/${PRODUCT}/patches.sh"

BRANCH="${PREFIX}-${VERSION}"

for dir in "$REPOS_DIR"/*; do
    [[ -d "$dir" ]] || continue
    cd "$dir"
    repo=$(basename "$dir")

    echo
    echo "$repo"

    # # check for uncommitted changes
    # if ! git diff --quiet || ! git diff --cached --quiet; then
    #     echo "ERROR: uncommitted changes in $repo"
    #     exit 1
    # fi

    git show-ref --verify --quiet "refs/heads/$BRANCH" || { echo "skip: $repo has no $BRANCH branch"; continue; }
    git checkout "$BRANCH"

    apply_patches "$repo"

    lp_tag=$(git tag -l "${PREFIX}-v${VERSION}*" | head -1)
    [[ -n "$lp_tag" ]] || { echo "ERROR: no ${PREFIX}-v${VERSION}* tag found"; exit 1; }

    # only retag if tag doesn't exist or points to wrong commit
    if [[ $(git rev-parse "$lp_tag^{}") != $(git rev-parse HEAD) ]]; then
        git tag -f --no-sign "$lp_tag"
    fi
done
