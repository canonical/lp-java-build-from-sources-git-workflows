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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="${SCRIPT_DIR}/opensearch-repos"
PREFIX="${PREFIX:-lp}"

JFROG_URL="canonical.jfrog.io/artifactory/dataplatform-generic-stable-local/gradle"
errors=0

for VERSION in "${VERSIONS[@]}"; do
    echo "Processing version: ${VERSION}"
    for local_repo in "$REPO_BASE"/opensearch*; do
        [[ -d "$local_repo" ]] || continue
        [[ "$(basename "$local_repo")" == "opensearch-build" ]] && continue
        cd "$local_repo"

        repo_name=$(basename "$local_repo")
        lp_branch="${PREFIX}-${VERSION}"

        echo ""
        echo "**** ${repo_name} ****"

        # check the branch exists
        if ! git rev-parse --verify "$lp_branch" &>/dev/null; then
            echo "$lp_branch branch not found"
            ((errors++))
            continue
        fi

        # check on correct branch
        current_branch=$(git branch --show-current)
        if [[ "$current_branch" != "$lp_branch" ]]; then
            echo "not on $lp_branch (on $current_branch)"
            ((errors++))
            continue
        else
            echo "on ${current_branch}"
        fi

        # check gradle patch applied
        wrapper=$(find . -path "*/gradle/wrapper/gradle-wrapper.properties" -print -quit)
        if [[ -n "$wrapper" ]]; then
            if grep -q "$JFROG_URL" "$wrapper"; then
                echo "gradle patched for ${repo_name}"
            else
                echo "gradle patch not applied for ${repo_name}"
                ((errors++))
            fi
        fi

        # check tag exists
        lp_tag=$(git tag -l "${PREFIX}-v${VERSION}*" | head -1)
        if [[ -z "$lp_tag" ]]; then
            echo "tag not found for ${repo_name}"
            ((errors++))
            continue
        else
            echo "tag set to ${lp_tag}"
        fi

        # check tag points to latest commit
        tag_commit=$(git rev-list -n1 "$lp_tag")
        head_commit=$(git rev-parse HEAD)
        if [[ "$tag_commit" == "$head_commit" ]]; then
            echo "tag at HEAD for ${repo_name}"
        else
            echo "tag not at HEAD (tag: ${tag_commit:0:7}, HEAD: ${head_commit:0:7})"
            ((errors++))
        fi

        # check remote configured
        if ! git remote get-url launchpad &>/dev/null; then
            echo "remote 'launchpad' not configured for ${repo_name}"
            ((errors++))
        fi
    done

    echo ""
    if [[ $errors -gt 0 ]]; then
        echo "not pushing"
        exit 1
    fi

    echo ""
    read -p "Push to launchpad? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || {
        echo "aborted"
        exit 0
    }

    # push
    for local_repo in "$REPO_BASE"/opensearch*; do
        [[ -d "$local_repo" ]] || continue

        [[ "$(basename "$local_repo")" == "opensearch-build" ]] && continue

        cd "$local_repo"

        repo_name=$(basename "$local_repo")
        lp_branch="${PREFIX}-${VERSION}"
        lp_tag=$(git tag -l "${PREFIX}-v${VERSION}*" | head -1)

        echo "Pushing ${repo_name}..."
        git push -u launchpad "$lp_branch"
        git push launchpad --delete "$lp_tag" 2>/dev/null || true
        git push launchpad "$lp_tag"
    done

    # push non opensearch repos
    for local_repo in "$REPO_BASE"/python-* "$REPO_BASE"/googletest; do
        [[ -d "$local_repo" ]] || continue
        cd "$local_repo"

        repo_name=$(basename "$local_repo")

        main_branch="main"
        if [[ "$repo_name" == *nmslib* ]]; then
            main_branch="master"
        fi

        git push -f --set-upstream launchpad "$main_branch"
    done

done

echo "all repos pushed to launchpad"