#!/usr/bin/env bash

set -eux

usage() {
    cat >&2 <<EOF
Usage: ${0##*/} -v VERSION [-v VERSION ...]

Bridges upstream OpenSearch repos into Launchpad for the given release(s).

Options:
  -v VERSION       Release version to process (e.g. 2.19.5); repeatable
  -h               Show this help

Example:
  ${0##*/} -v 2.18.0 -v 2.19.5
EOF
}

declare -a VERSIONS=()

while getopts ":v:h" opt; do
    case "${opt}" in
        v) VERSIONS+=("${OPTARG}") ;;
        h) usage; exit 0 ;;
        :) echo "Error: -${OPTARG} requires an argument" >&2; usage; exit 1 ;;
        \?) echo "Error: unknown option -${OPTARG}" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ "${#VERSIONS[@]}" -eq 0 ]; then
    echo "Error: at least one VERSION (-v) is required" >&2
    usage
    exit 1
fi

PREFIX="${PREFIX:-lp}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="${SCRIPT_DIR}/opensearch-repos"

remote_url="distributionUrl=https\\\:\/\/services.gradle.org\/distributions"
jfrog_url="distributionUrl=https\\\:\/\/canonical.jfrog.io\/artifactory\/dataplatform-generic-stable-local\/gradle"

for project in "$REPO_BASE"/opensearch*; do
    [[ -d "$project" ]] || continue
    cd "${project}" || exit 1

    if [[ "${project}" == *python ]]; then
        continue
    fi

    for version in "${VERSIONS[@]}"; do
        if git rev-parse --verify "${PREFIX}-${version}" >/dev/null 2>&1; then
            git checkout "${PREFIX}-${version}"
        else
            echo "Branch ${PREFIX}-${version} not found in ${project}, skipping"
            continue
        fi

        gradle_wrapper="gradle/wrapper/gradle-wrapper.properties"
        if [[ "${project}" == *notifications* ]]; then
            gradle_wrapper="notifications/${gradle_wrapper}"
        fi

        sed -i -e "s/^${remote_url}\+/${jfrog_url}/g" "${gradle_wrapper}"
        sed -i -e "s/^# distributionSha256Sum\+/distributionSha256Sum/g" "${gradle_wrapper}"

        echo "New distributionUrl line:"
        grep "^distributionUrl=" "${gradle_wrapper}" || true

        echo "New distributionSha256Sum line:"
        grep "^distributionSha256Sum" "${gradle_wrapper}" || true

        git add -A
        if ! git diff --cached --quiet; then
            git commit -m "changed gradle distro url"
            echo "committed patch in ${project}"
        else
            echo "no changes in ${project}"
        fi
        # git push launchpad "${PREFIX}-${version}"
        #

        if [[ "${project}" == *opensearch-k-nn ]]; then
            sed -i \
                -e 's|https://github.com/nmslib/nmslib.git|https://git.launchpad.net/~data-platform/opensearch-project-components/+git/python-nmslib|' \
                -e 's|https://github.com/facebookresearch/faiss.git|https://git.launchpad.net/~data-platform/opensearch-project-components/+git/python-faiss|' \
                .gitmodules

            sed -i "s|cut -d ' ' -f3|cut -d ' ' -f4|" scripts/build.sh

            git add -A
            if ! git diff --cached --quiet; then
                git commit -m "Change git submodules and gcc version parsing"
                echo "committed k-nn patches"
            fi
        fi

        # we dont need the following patch for 3.x as rca is deprecated
        if [[ "${project}" == *opensearch-performance-analyzer ]] && [[ "${version}" == 2* ]]; then
            sed -i \
                -e 's|https://github.com/opensearch-project/performance-analyzer-rca.git|git://git.launchpad.net/~data-platform/opensearch-project-components/+git/opensearch-performance-analyzer-rca|' \
                -e "s|\${rcaProjectFetch}/2.x|\${rcaProjectFetch}/${PREFIX}-${version}|" \
                build.gradle

            git add -A
            if ! git diff --cached --quiet; then
                git commit -m "update lp remote rca"
                echo "committed performance-analyzer RCA patch"
            fi
        fi

        version_tag="$(git tag -l --sort=version:refname "${PREFIX}-v${version}*" | tail -1)"
        if [[ -z "${version_tag}" ]]; then
            echo "Skipping ${version}: version_tag '${version_tag}' is invalid or not found"
            continue
        fi
        GIT_EDITOR=: git tag "${version_tag}" --force
        # git push launchpad "${version_tag}" --force

    done
done