#!/usr/bin/env bash
set -eu

command -v yq >/dev/null || { echo "yq is required"; exit 1; }

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOS_DIR="${ROOT_DIR}/repos/${PRODUCT}"

. "${ROOT_DIR}/config.sh"
. "${ROOT_DIR}/${PRODUCT}/config.sh"

# fetch manifest
MANIFEST_URL="https://raw.githubusercontent.com/opensearch-project/opensearch-build/${OPENSEARCH_BUILD_REF}/manifests/${VERSION}/${PRODUCT}-${VERSION}.yml"

repos=$(curl -s "$MANIFEST_URL" \
    | yq '.components[].repository' \
    | grep 'github.com/opensearch-project/' \
    | grep -v 'functional-test' \
    | sed 's|https://github.com/opensearch-project/||; s|\.git$||')

if [[ "$PRODUCT" == "opensearch" ]]; then
    repos+=$'\nopensearch-prometheus-exporter'
    repos+=$'\nperformance-analyzer-rca'
fi

repos=$(echo "$repos" | sort -u)

checkout_or_create_branch() {
    local branch="$1"
    local upstream_ref="$2"
    local upstream_commit
    upstream_commit=$(git rev-parse "${upstream_ref}^{}")

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo "Checkout existing $branch"
        git checkout "$branch"
        if ! git merge-base --is-ancestor "$upstream_commit" HEAD; then
            echo "ERROR: $branch exists and isn't based on $upstream_ref"
            exit 1
        fi
    else
        git checkout -b "$branch" "$upstream_commit"
        echo "Created LP branch ${branch}"
    fi
}

mkdir -p "$REPOS_DIR"

while read -r repo; do
    local_name="$(echo "$repo" | tr '[:upper:]' '[:lower:]')"
    if [[ "$PRODUCT" == "opensearch" ]]; then
        case "$local_name" in
            opensearch|opensearch-*) ;;
            *) local_name="opensearch-${local_name}" ;;
        esac
    fi

    echo "$repo"
    cd "$REPOS_DIR"

    if [[ ! -d "$local_name" ]]; then
        echo "Cloning into '$local_name'..."
        git clone -q --filter=blob:none --single-branch --branch main \
            "https://github.com/opensearch-project/${repo}.git" "$local_name"
    fi

    cd "$local_name"

    # # check for uncommitted changes
    # if ! git diff --quiet || ! git diff --cached --quiet; then
    #     echo "ERROR: uncommitted changes in $local_name"
    #     exit 1
    # fi

    # git fetch -q origin --tags || { echo "ERROR: failed to fetch origin tags"; exit 1; }

    # get upstream branch (performance-analyzer-rca doesn't use tags)
    if [[ "$repo" == "performance-analyzer-rca" ]]; then
        case "$VERSION" in
            2*)
                git fetch -q origin 2.x:refs/remotes/origin/2.x || { echo "ERROR: failed to fetch origin 2.x"; exit 1; }
                checkout_or_create_branch "${PREFIX}-${VERSION}" "origin/2.x"
                ;;
            3*)
                git fetch -q origin main || { echo "ERROR: failed to fetch origin main"; exit 1; }
                checkout_or_create_branch "${PREFIX}-${VERSION}" "origin/main"
                ;;
        esac
        version_tag="${VERSION}.0"
    else
        # get upstream tag for this version
        # ref_name="${VERSION}.*"
        # [[ "$repo" == "OpenSearch" ]] && ref_name="${VERSION}"
        # [[ "$repo" == "OpenSearch-Dashboards" ]] && ref_name="${VERSION}"
        #
        # version_tag=$(git tag -l --sort=-version:refname "$ref_name" | head -1)
        # [[ -n "$version_tag" ]] || { echo "ERROR: no upstream tag matching $ref_name"; exit 1; }
        version_tag="${VERSION}.0"
        [[ "$repo" == "OpenSearch" ]] && version_tag="${VERSION}"
        [[ "$repo" == "OpenSearch-Dashboards" ]] && version_tag="${VERSION}"

        git fetch -q origin tag ${version_tag} || { echo "ERROR: tag ${version_tag} not found"; exit 1; }
        checkout_or_create_branch "${PREFIX}-${VERSION}" "$version_tag"
    fi

    git remote remove launchpad 2>/dev/null || true
    git remote add launchpad "${LP_REMOTE}/${local_name}"

    lp_tag="${PREFIX}-v${version_tag}"

    # tag if tag doesn't exist or points to wrong commit
    if ! git show-ref --verify --quiet "refs/tags/$lp_tag" || [[ $(git rev-parse "$lp_tag^{}") != $(git rev-parse HEAD) ]]; then
        git tag -f --no-sign "$lp_tag"
        echo " Created tag ${lp_tag} from upstream ${version_tag}"
    fi
    echo
    #
    # if [[ "$repo" == "opensearch-prometheus-exporter" ]]; then
    #     # .gitattributes in this repo forces crlf changes
    #     #  git checkout -- gradlew.bat doesn't work so ignore changes to the file
    #     git update-index --skip-worktree gradlew.bat
    # fi

done <<< "$repos"
