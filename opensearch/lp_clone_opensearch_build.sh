#!/usr/bin/env bash
set -eux

usage() {
    echo "Usage: $0 --lp-user <user> --last-version <version> --new-version <version>"
    echo "  e.g. $0 --lp-user jdoe --last-version 2.19.4 --new-version 2.19.5"
    exit 1
}

LP_USER=""
LAST_VERSION=""
NEW_VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lp-user)
            LP_USER="$2"
            shift 2
            ;;
        --last-version)
            LAST_VERSION="$2"
            shift 2
            ;;
        --new-version)
            NEW_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$LP_USER" || -z "$LAST_VERSION" || -z "$NEW_VERSION" ]]; then
    echo "--lp-user, --last-version and --new-version are all required"
    usage
fi


SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="${SCRIPT_DIR}/opensearch-repos"

PREFIX="${PREFIX:-lp}"

LP_REPO="git+ssh://${LP_USER}@git.launchpad.net/soss/+source/opensearch-build"
UPSTREAM_REPO="https://github.com/opensearch-project/opensearch-build.git"

mkdir -p "$REPO_BASE"
cd "$REPO_BASE"

if [ -d "opensearch-build" ]; then
    cd opensearch-build
else
    git clone "$LP_REPO" opensearch-build
    cd opensearch-build
fi

git remote remove upstream 2>/dev/null || true
git remote add upstream "$UPSTREAM_REPO"
git fetch upstream --tags

git checkout "lp-${LAST_VERSION}"
git checkout -B "${PREFIX}-${NEW_VERSION}"

echo "merging upstream ${NEW_VERSION} tag..."
# merge upstream tag (there might be conflicts)
git merge "${NEW_VERSION}" --no-edit 