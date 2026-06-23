#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"

OPENSEARCH_BUILD_DIR="${ROOT_DIR}/opensearch-build"
LAST_BRANCH="lp-${LAST_VERSION}"
BRANCH="${PREFIX}-${VERSION}"
LP_BUILD_REMOTE="${LP_SOSS_REMOTE}/opensearch-build"
UPSTREAM="https://github.com/opensearch-project/opensearch-build.git"

if [[ ! -d "$OPENSEARCH_BUILD_DIR" ]]; then
    echo "Cloning into 'opensearch-build'..."
    git clone -q "$LP_BUILD_REMOTE" "$OPENSEARCH_BUILD_DIR"
fi

cd "$OPENSEARCH_BUILD_DIR"

# check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: uncommitted changes in opensearch-build"
    exit 1
fi

git remote remove upstream 2>/dev/null || true
git remote add upstream "$UPSTREAM"
git fetch -q upstream --tags || { echo "ERROR: failed to fetch upstream tags"; exit 1; }
git fetch -q origin || { echo "ERROR: failed to fetch origin"; exit 1; }

if git rev-parse --verify "origin/$LAST_BRANCH" >/dev/null 2>&1; then
    git checkout -B "$LAST_BRANCH" "origin/$LAST_BRANCH"
    git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
    if ! git merge-base --is-ancestor "${VERSION}" HEAD; then
        git merge "${VERSION}" --no-edit
        echo "on branch $BRANCH, merged upstream ${VERSION}"
    else
        echo "on branch $BRANCH, upstream ${VERSION} already merged"
    fi
else
    echo "no $LAST_BRANCH branch found, creating $BRANCH from upstream tag"
    git checkout -B "$BRANCH" "${VERSION}"
    echo "on branch $BRANCH, based on upstream ${VERSION}"
fi
