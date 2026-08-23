#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"

OPENSEARCH_BUILD_DIR="${ROOT_DIR}/repos/opensearch-build"
BRANCH="${PREFIX}-${VERSION}"
LP_REMOTE="${LP_SOSS_REMOTE}/opensearch-build"
UPSTREAM="https://github.com/opensearch-project/opensearch-build.git"

if [[ ! -d "$OPENSEARCH_BUILD_DIR" ]]; then
    mkdir -p "$(dirname "$OPENSEARCH_BUILD_DIR")"
    echo "Cloning into 'opensearch-build'..."
    git clone -q "$UPSTREAM" "$OPENSEARCH_BUILD_DIR"
fi

cd "$OPENSEARCH_BUILD_DIR"

# check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: uncommitted changes in opensearch-build"
    exit 1
fi

git fetch -q origin --tags || { echo "ERROR: failed to fetch origin tags"; exit 1; }

git rev-parse "${OPENSEARCH_BUILD_REF}" >/dev/null 2>&1 || { echo "ERROR: ref ${OPENSEARCH_BUILD_REF} not found"; exit 1; }

if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    git checkout "$BRANCH"
    if ! git merge-base --is-ancestor "${OPENSEARCH_BUILD_REF}" HEAD; then
        echo "ERROR: local opensearch-build branch '$BRANCH' exists and isn't based on ${OPENSEARCH_BUILD_REF}"
        exit 1
    fi
else
    git checkout -B "$BRANCH" "${OPENSEARCH_BUILD_REF}"
fi

git remote remove launchpad 2>/dev/null || true
git remote add launchpad "$LP_REMOTE"
