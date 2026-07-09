#!/usr/bin/env bash
set -eu

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STAGING_REPO="dataplatform-opensearch-staging"
LOCAL_REPO="dataplatform-opensearch-maven-local"
CACHE_DIR="${ROOT_DIR}/artifacts/jfrog-caches"

mkdir -p "$CACHE_DIR"

# get all artifacts in local repo
echo "Fetching dataplatform-opensearch-maven-local repo contents..."
jf rt search "${LOCAL_REPO}/**" | jq -r '.[].path' | sed "s|^${LOCAL_REPO}/||" | sort > "${CACHE_DIR}/local.txt"

remotes=$(jf rt curl -XGET "/api/repositories/${STAGING_REPO}" 2>/dev/null | jq -r '.repositories[]' | grep remote)

echo ""
echo "Remote repos found:"
echo "$remotes"
echo ""

for repo in $remotes; do
    cache="${repo}-cache"
    echo ""
    echo "Checking ${cache}..."

    # get all artifacts in repo cache
    jf rt search "${cache}/**" 2>/dev/null | jq -r '.[].path' | sed "s|^${cache}/||" | sort > "${CACHE_DIR}/${cache}.txt"

    # find artifacts in this cache and not in local repo
    missing=$(comm -23 "${CACHE_DIR}/${cache}.txt" "${CACHE_DIR}/local.txt")

    if [[ -z "$missing" ]]; then
        echo "No new artifacts"
        continue
    fi

    count=$(echo "$missing" | wc -l | tr -d ' ')
    dirs=$(echo "$missing" | xargs -n1 dirname | sort -u)
    dir_count=$(echo "$dirs" | wc -l | tr -d ' ')
    echo "Found ${count} uncopied artifacts in ${dir_count} directories, copying..."

    # echo "$dirs" | xargs -P 8 -I {} echo "jf rt copy "${cache}/{}/*" "${LOCAL_REPO}/" --flat=false"
    echo "$dirs" | xargs -P 8 -I {} jf rt copy "${cache}/{}/*" "${LOCAL_REPO}/"
done

echo "Done"
