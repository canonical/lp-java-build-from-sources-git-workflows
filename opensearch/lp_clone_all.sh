#!/usr/bin/env bash

set -eux

usage() {
    cat >&2 <<EOF
Usage: ${0##*/} -u LP_USERNAME -v VERSION [-v VERSION ...]

Bridges upstream OpenSearch repos into Launchpad for the given release(s).

Options:
  -u LP_USERNAME   Launchpad username (e.g. lp-username)
  -v VERSION       Release version to process (e.g. 2.19.5); repeatable
  -h               Show this help

Example:
  ${0##*/} -u lp-username -v 2.18.0 -v 2.19.5
EOF
}

LP_USERNAME=""
declare -a VERSIONS=()

while getopts ":u:v:h" opt; do
    case "${opt}" in
        u) LP_USERNAME="${OPTARG}" ;;
        v) VERSIONS+=("${OPTARG}") ;;
        h) usage; exit 0 ;;
        :) echo "Error: -${OPTARG} requires an argument" >&2; usage; exit 1 ;;
        \?) echo "Error: unknown option -${OPTARG}" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "${LP_USERNAME}" ] || [ "${#VERSIONS[@]}" -eq 0 ]; then
    echo "Error: LP_USERNAME (-u) and at least one VERSION (-v) are required" >&2
    usage
    exit 1
fi

declare -a REPOS=(
    OpenSearch
    common-utils
    opensearch-remote-metadata-sdk
    opensearch-system-templates
    job-scheduler
    k-NN
    geospatial
    security
    cross-cluster-replication
    ml-commons
    neural-search
    notifications
    observability
    reporting
    sql
    asynchronous-search
    anomaly-detection
    flow-framework
    skills
    alerting
    security-analytics
    index-management
    performance-analyzer
    custom-codecs
    query-insights
    opensearch-learning-to-rank-base
    performance-analyzer-rca
    opensearch-prometheus-exporter
)
LP_SOSS_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/soss/+source"
LP_PUBLIC_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/~data-platform/opensearch-project-components/+git" # opensearch-project-components

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="${SCRIPT_DIR}/opensearch-repos"

# If repo base directory doesn't exist, create it
if [ ! -d "${REPO_BASE}" ]; then
    mkdir -p "${REPO_BASE}"
fi


for repo in "${REPOS[@]}"; do

    echo "${repo}"

    cd "${REPO_BASE}"

    # clone main branch of upstream repo
    local_repo="$(echo "${repo}" | awk '{print tolower($0)}')"
    if [[ ${local_repo} != opensearch* ]]; then
        local_repo="opensearch-${local_repo}"
    fi

    echo "$local_repo"

    if [[ "${repo}" == "performance-analyzer-rca" ]]; then
        [ -d "${local_repo}" ] || git clone \
            "https://github.com/opensearch-project/${repo}.git" "${local_repo}"
    else
        [ -d "${local_repo}" ] || git clone --single-branch --branch main \
            "https://github.com/opensearch-project/${repo}.git" "${local_repo}"
    fi

    cd "${local_repo}" || exit 1

    git remote -v

    # fetch all tags
    git fetch --all --tags
    git checkout -- . 2>/dev/null || true

    # add launchpad remote for push
    lp_remote="${LP_PUBLIC_REMOTE}"
    if [[ "${repo}" == "opensearch-build" ]]; then
        lp_remote="${LP_SOSS_REMOTE}"
    fi
    git remote add launchpad "${lp_remote}/${local_repo}" || true


    for version in "${VERSIONS[@]}"; do
        GH_BRANCH="${version}"
        LP_BRANCH="lp-${version}"


        # add remote version branch
        if [[ "${repo}" == "performance-analyzer-rca" ]]; then
            source_ref="origin/2.x"
            version_tag="${version}.0"
            GH_BRANCH="2.x"
        else
            # tag format may change between build project and components
            ref_name="${version}.*"
            if [ "${repo}" == "opensearch-build" ] || [ "${repo}" == "OpenSearch" ]; then
                ref_name="${version}"
            fi

            # get version / release tag and associated commit
            version_tag="$(git tag -l --sort=version:refname "${ref_name}" | tail -1)"
            if [[ -z "${version_tag}" ]]; then
                echo "Skipping ${repo} ${version}: no matching tag for ${ref_name}"
                continue
            fi
            source_ref="${version_tag}"
        fi
        gh_release_commit="$(git rev-list -n1 "${source_ref}")"

        # checkout version branch
        git checkout -f -B "${GH_BRANCH}" "${gh_release_commit}"

        # create lp branch based on the version branch
        git checkout -B "${LP_BRANCH}"

        # fetch current version's latest tag and tag current
        lp_tag_name="lp-v${version_tag}"
        git tag -a "${lp_tag_name}" "${gh_release_commit}" -m "tagging commit with tag: ${lp_tag_name}" --force

    done
done

# ------------------------

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