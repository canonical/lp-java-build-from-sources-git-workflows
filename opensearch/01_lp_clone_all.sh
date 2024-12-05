#!/usr/bin/env bash

set -eux

if [ -z "${LP_USERNAME:-}" ]; then
    echo "Call this command as follows:"
    echo "$ LP_USERNAME=<your-launchpad-username> ./<command>"
    exit 1
fi

declare -a VERSIONS=("2.16.0")

LP_SOSS_REMOTE="git+ssh://$LP_USERNAME@git.launchpad.net/soss/+source"
LP_PUBLIC_REMOTE="git+ssh://$LP_USERNAME@git.launchpad.net/~data-platform/+git" # opensearch-project-components

function opensearch_git_checkout() {
    for repo in "${REPOS[@]}"; do
        echo "${repo}"

        pushd ../.. || exit 1

        # clone main branch of upstream repo
        local_repo="$(echo "${repo}" | awk '{print tolower($0)}')"
        if [[ ${local_repo} != opensearch* ]]; then
            local_repo="opensearch-${local_repo}"
        fi

        echo "$local_repo"

        [ -d "${local_repo}" ] || git clone --single-branch --branch main "$1/${repo}.git" "${local_repo}"
        pushd "${local_repo}" || exit 1

        git remote -v
        # fetch all tags
        # git pull
        git fetch --all --tags

        # add launchpad remote for push
        lp_remote="${LP_PUBLIC_REMOTE}"
        if [[ "${repo}" == "opensearch-build" ]]; then
            lp_remote="${LP_SOSS_REMOTE}"
        fi
        git remote add launchpad "${lp_remote}/${local_repo}" || true

        # TODO: add case of opensearch-performance-analyzer-rca:
        # - pull branch on rca (not tag based)
        # - checkout new lp-version branch out of it
        # - change branch name on build.gradle of performance-analyzer (add lp- prefix)

        for version in "${VERSIONS[@]}"; do
            GH_BRANCH="${version}"
            LP_BRANCH="lp-${version}"

            # add remote version branch
            if [[ "${version}" > "2\.9" ]]; then
                GH_BRANCH="main"
            fi
            git remote set-branches --add "origin" "${GH_BRANCH}"

            # tag format may change between build project and components
            ref_name="${version}.*"
            if [ "${repo}" == "opensearch-build" ] || [ "${repo}" == "OpenSearch" ]; then
                ref_name="${version}"
            fi

            # get version / release tag and associated commit
            version_tag="$(git tag -l --sort=version:refname "${ref_name}" | tail -1)"
            gh_release_commit="$(git show-ref -s "${version_tag}")"

            # checkout version branch
            git checkout -b "${GH_BRANCH}" "${gh_release_commit}"

            # create lp branch based on the version branch
            git checkout -b "${LP_BRANCH}"

            # fetch current version's latest tag and tag current
            lp_tag_name="lp-v${version_tag}"
            git tag -a "${lp_tag_name}" "${gh_release_commit}" -m "tagging commit with tag: ${lp_tag_name}" --force

            # push lp version branch to LP
            git push --set-upstream launchpad "${LP_BRANCH}"
            git push launchpad --delete "${lp_tag_name}" || true
            git push launchpad "${lp_tag_name}"

            # delete default main remote LP branch
            git push launchpad --delete main || true
        done

        popd || exit 1
        popd || exit 1
    done
}

declare -a REPOS=(
    opensearch-build
    OpenSearch
    common-utils
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
    alerting
    security-analytics
    index-management
    performance-analyzer
    custom-codecs
    skills
    flow-framework
    query-insights
)
opensearch_git_checkout "https://github.com/opensearch-project"

# ------------------------

declare -a REPOS=(
    prometheus-exporter-plugin-for-opensearch
)
opensearch_git_checkout "https://github.com/aiven-Open"

# ------------------------

# performance analyzer RCA, and faiss and nmslib
declare -a ALTERNATE_REPOS=(
    https://github.com/opensearch-project/performance-analyzer-rca.git
    https://github.com/facebookresearch/faiss.git
    https://github.com/nmslib/nmslib.git
    https://github.com/google/googletest.git
)
for repo in "${ALTERNATE_REPOS[@]}"; do
    echo "${repo}"

    pushd ../.. || exit 1

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
    pushd "${local_repo}" || exit 1

    # fetch all tags
    git pull
    git fetch --all --tags

    # add launchpad remote for push
    git remote add launchpad "${LP_PUBLIC_REMOTE}/${local_repo}" || true

    # push lp version branch to LP
    git push -f --set-upstream launchpad "${main_branch}"

    # rename default main branch created by soss
    git push launchpad --delete old_main || true

    popd || exit 1
    popd || exit 1
done
