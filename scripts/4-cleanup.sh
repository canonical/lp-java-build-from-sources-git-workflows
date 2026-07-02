#!/usr/bin/env bash
set -eu

PRODUCT="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"

REPO_BASE="${ROOT_DIR}/repos/${PRODUCT}"
BRANCH="${PREFIX}-${VERSION}"
TAG_PATTERN="${PREFIX}-v${VERSION}"

if [[ ! -d "$REPO_BASE" ]]; then
    echo "ERROR: $REPO_BASE does not exist"
    exit 1
fi

repos=()
for dir in "$REPO_BASE"/*; do
    [[ -d "$dir/.git" ]] && repos+=("$dir")
done

if [[ ${#repos[@]} -eq 0 ]]; then
    echo "No repos found in $REPO_BASE"
    exit 0
fi

echo "Will delete from launchpad remote:"
echo "  Branch: $BRANCH"
echo "  Tags:   ${TAG_PATTERN}*"
echo "  Repos:  ${#repos[@]}"
echo
read -p "Proceed? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo
for dir in "${repos[@]}"; do
    repo=$(basename "$dir")
    cd "$dir"

    git remote get-url launchpad >/dev/null 2>&1 || continue

    git push launchpad --delete "$BRANCH" 2>/dev/null && echo "$repo: deleted branch $BRANCH"

    tag=$(git ls-remote launchpad "refs/tags/${TAG_PATTERN}*" 2>/dev/null | head -1 | awk '{print $2}' | sed 's|refs/tags/||')
    [[ -n "$tag" ]] && git push launchpad --delete "$tag" && echo "$repo: deleted tag $tag"
done

echo "Done."
