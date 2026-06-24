#!/usr/bin/env bash

push_to_launchpad() {
    local branch="${1:-$BRANCH}"
    local prefix="${2:-$PREFIX}"
    local version="${3:-$VERSION}"
    
    local repo=$(basename "$PWD")

    # 1. Check for Launchpad remote
    if ! git remote get-url launchpad >/dev/null 2>&1; then
        echo "ERROR: no launchpad remote in $repo"
        exit 1
    fi

    # 2. Find the tag
    local lp_tag=$(git tag -l "${prefix}-v${version}*" | head -1)
    if [ -z "$lp_tag" ]; then
        echo "ERROR: no tag found in $repo"
        exit 1
    fi

    # 3. Check if tag's commit matches HEAD
    local local_head=$(git rev-parse HEAD)
    local local_tag=$(git rev-parse "$lp_tag^{}")

    if [ "$local_head" != "$local_tag" ]; then
        echo "ERROR: tag $lp_tag not at HEAD in $repo"
        echo "HEAD: $(echo "$local_head" | cut -c1-7)"
        echo "tag:  $(echo "$local_tag" | cut -c1-7)"
        exit 1
    fi

    # 4. Check remote status
    local remote_head=$(git ls-remote launchpad "refs/heads/$branch" 2>/dev/null | cut -f1)
    local remote_tag=$(git ls-remote launchpad "refs/tags/${lp_tag}^{}" 2>/dev/null | cut -f1)

    if [ "$local_head" = "$remote_head" ] && [ "$local_tag" = "$remote_tag" ]; then
        echo "$repo is already up to date."
        # Use return 0 here to safely skip to the next repo in your loop
        return 0
    fi

    # 5. Push to remote
    echo "Pushing branch '$branch' and tag '$lp_tag' for $repo to launchpad..."
    git fetch launchpad 2>/dev/null || true
    git push -u launchpad "$branch"
    git push launchpad "$lp_tag" --force
}