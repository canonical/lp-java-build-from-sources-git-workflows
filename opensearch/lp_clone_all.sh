#!/usr/bin/env bash

set -eux

# Make sure $PRODUCT, $VERSION, $PREFIX, $LP_USERNAME and $LP_PUBLIC_REMOTE are set in the environment before running this script
if [[ -z "${PRODUCT}" || -z "${VERSION}" || -z "${PREFIX}" || -z "${LP_USERNAME}" ]]; then
    echo "ERROR: PRODUCT, VERSION, PREFIX, and LP_USERNAME must be set in the environment"
    exit 1
fi

export LP_SOSS_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/soss/+source"
# If the product is opensearch-dashboards, use the dashboards remote
if [[ "${PRODUCT}" == "opensearch-dashboards" ]]; then
    export LP_PUBLIC_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/~data-platform/opensearch-project-dashboards-components/+git"
else
    export LP_PUBLIC_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/~data-platform/opensearch-project-components/+git" # opensearch-project-components
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# TODO: Once we can rename "opensearch" folder to "scripts" (mainly last step of PR review) replace path
REPO_BASE="${ROOT_DIR}/opensearch/${PRODUCT}-repos"

REPOS_FILE="${REPO_BASE}/repos.txt"

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
        if [[ "$repo" == "performance-analyzer-rca" ]]; then
            git clone -q "https://github.com/opensearch-project/${repo}.git" "$local_name"
        else
            git clone -q --single-branch --branch main \
                "https://github.com/opensearch-project/${repo}.git" "$local_name"
        fi
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
                git fetch -q origin 2.x || { echo "ERROR: failed to fetch origin 2.x"; exit 1; }
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
    git remote add launchpad "${LP_PUBLIC_REMOTE}/${local_name}"

    lp_tag="${PREFIX}-v${version_tag}"

    # only tag if tag doesn't exist or points to wrong commit
    if ! git rev-parse "$lp_tag^{}" >/dev/null 2>&1 || [[ $(git rev-parse "$lp_tag^{}") != $(git rev-parse HEAD) ]]; then
        git tag -f "$lp_tag" -m "$lp_tag"
        echo " Created tag ${lp_tag} from upstream ${version_tag}"
    fi

done < "$REPOS_FILE"

# If the product is opensearch, clone the alternate repos
if [[ "${PRODUCT}" == "opensearch" ]]; then

    # performance analyzer RCA, and faiss and nmslib
    declare -a ALTERNATE_REPOS=(
        https://github.com/facebookresearch/faiss.git
        https://github.com/nmslib/nmslib.git
        https://github.com/google/googletest.git
    )
    for repo in "${ALTERNATE_REPOS[@]}"; do
        echo "${repo}"

        cd "${REPO_BASE}"

        local_repo="$(echo "${repo}" | awk '{print tolower($0)}' | awk -F/ '{print $NF}' | awk -F. '{print $1}')"
        if [[ ${repo} == *opensearch-project* ]]; then
            local_repo="opensearch-${local_repo}"
        elif [[ ${repo} != *googletest* ]]; then
            local_repo="python-${local_repo}"
        fi

        main_branch="main"
        if [[ "${repo}" == *nmslib* ]]; then
            main_branch="master"
        fi
        [ -d "${local_repo}" ] || git clone --single-branch --branch "${main_branch}" "${repo}" "${local_repo}"
        cd "${local_repo}" || exit 1

        # fetch all tags
        git pull
        git fetch --all --tags

        # add launchpad remote for push
        git remote remove launchpad 2>/dev/null || true
        git remote add launchpad "${LP_PUBLIC_REMOTE}/${local_repo}"

    done
fi