#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"
PRODUCT_DIR="${ROOT_DIR}/${PRODUCT}"
REPO_BASE="${ROOT_DIR}/repos/${PRODUCT}"
. "${PRODUCT_DIR}/config.sh"

REPOS_FILE="${PRODUCT_DIR}/repos.txt"

checkout_or_create_branch() {
    local branch="$1"
    local base_commit="$2"
    local base_name="$3"

    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
        echo "Checkout existing $branch"
        git checkout "$branch"
        if ! git merge-base --is-ancestor "$base_commit" HEAD; then
            echo "ERROR: $branch exists and isn't based on $base_name"
            exit 1
        fi
    else
        git checkout -B "$branch" "$base_commit"
        echo "Created LP branch ${branch}"
    fi
}

mkdir -p "$REPO_BASE"

if [[ ! -f "$REPOS_FILE" ]]; then
    echo "repos.txt not found. Run parse_manifest.py"
    exit 1
fi

while read -r repo; do
    local_name="$(echo "$repo" | tr '[:upper:]' '[:lower:]')"
    if [[ "$PRODUCT" == "opensearch" ]]; then
        case "$local_name" in
            opensearch|opensearch-*) ;;
            *) local_name="opensearch-${local_name}" ;;
        esac
    fi

    echo
    echo "$repo"
    cd "$REPO_BASE"

    if [[ ! -d "$local_name" ]]; then
        echo "Cloning into '$local_name'..."
        git clone -q --filter=blob:none --single-branch --branch main \
            "https://github.com/opensearch-project/${repo}.git" "$local_name"
    fi

    cd "$local_name"

    # check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "ERROR: uncommitted changes in $local_name"
        exit 1
    fi

    git fetch -q origin --tags || { echo "ERROR: failed to fetch origin tags"; exit 1; }

    # get upstream branch (performance-analyzer-rca doesn't use tags)
    if [[ "$repo" == "performance-analyzer-rca" ]]; then
        case "$VERSION" in
            2*)
                git fetch -q origin 2.x:refs/remotes/origin/2.x || { echo "ERROR: failed to fetch origin 2.x"; exit 1; }
                base_ref="origin/2.x"
                ;;
            3*)
                git fetch -q origin main || { echo "ERROR: failed to fetch origin main"; exit 1; }
                base_ref="origin/main"
                ;;
        esac
        base_commit=$(git rev-parse "$base_ref")
        checkout_or_create_branch "${PREFIX}-${VERSION}" "$base_commit" "$base_ref"
        version_tag="${VERSION}.0"
    else
        # get upstream tag for this version
        ref_name="${VERSION}.*"
        [[ "$repo" == "OpenSearch" ]] && ref_name="${VERSION}"
        [[ "$repo" == "OpenSearch-Dashboards" ]] && ref_name="${VERSION}"

        version_tag=$(git tag -l --sort=-version:refname "$ref_name" | head -1)
        [[ -n "$version_tag" ]] || { echo "ERROR: no upstream tag matching $ref_name"; exit 1; }

        # get upstream commit from tag, create LP branch
        release_commit=$(git rev-list -n1 "$version_tag")
        checkout_or_create_branch "${PREFIX}-${VERSION}" "$release_commit" "$version_tag"
    fi

    git remote remove launchpad 2>/dev/null || true
    git remote add launchpad "${LP_REMOTE}/${local_name}"

    lp_tag="${PREFIX}-v${version_tag}"

    # only tag if tag doesn't exist or points to wrong commit
    if ! git rev-parse "$lp_tag^{}" >/dev/null 2>&1 || [[ $(git rev-parse "$lp_tag^{}") != $(git rev-parse HEAD) ]]; then
        git tag -f "$lp_tag" -m "$lp_tag"
        echo " Created tag ${lp_tag} from upstream ${version_tag}"
    fi

done < "$REPOS_FILE"
