#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_BASE="${ROOT_DIR}/repos/${PRODUCT}"

. "${ROOT_DIR}/config.sh"

BRANCH="${PREFIX}-${VERSION}"

for dir in "$REPO_BASE"/*; do
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

    git show-ref --verify --quiet "refs/heads/$BRANCH" || { echo "skip: no $BRANCH branch"; continue; }
    git checkout "$BRANCH"
    git remote get-url launchpad || { echo "ERROR: no launchpad remote"; exit 1; }

    lp_tag=$(git tag -l "${PREFIX}-v${VERSION}*" | head -1)
    [[ -n "$lp_tag" ]] || { echo "ERROR: no tag"; exit 1; }

    # check if tag's commit matches head
    local_head=$(git rev-parse HEAD)
    local_tag=$(git rev-parse "$lp_tag^{}")

    if [[ "$local_head" != "$local_tag" ]]; then
        echo "ERROR: tag $lp_tag not at HEAD"
        echo "HEAD: $(echo "$local_head" | cut -c1-7)"
        echo "tag:  $(echo "$local_tag" | cut -c1-7)"
        exit 1
    fi

    remote_head=$(git ls-remote launchpad "refs/heads/$BRANCH" 2>/dev/null | cut -f1)
    remote_tag=$(git ls-remote launchpad "refs/tags/${lp_tag}^{}" 2>/dev/null | cut -f1)
    [[ -z "$remote_tag" ]] && remote_tag=$(git ls-remote launchpad "refs/tags/${lp_tag}" 2>/dev/null | cut -f1)

    if [[ "$local_head" == "$remote_head" && "$local_tag" == "$remote_tag" ]]; then
        echo "Already up to date."
        continue
    fi

    git fetch launchpad --quiet 2>/dev/null || true
    echo "Pushing branch '$BRANCH' and tag '$lp_tag' to launchpad..."
    git push launchpad "$BRANCH" --force
    git push launchpad "$lp_tag" --force
done

echo "Done."
echo
