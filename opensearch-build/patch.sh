#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"

OPENSEARCH_BUILD_DIR="${ROOT_DIR}/repos/opensearch-build"
PATCHES_DIR="${ROOT_DIR}/opensearch-build/patches"

cd "$OPENSEARCH_BUILD_DIR"

for patch in "$PATCHES_DIR"/*.patch; do
    if git apply --check --reverse "$patch" 2>/dev/null; then
        echo "Patch $(basename "$patch") already applied"
        continue
    fi
    git apply "$patch"
    git add -A
    git diff --cached --quiet || git commit -m "$(basename "$patch" .patch)"
done

if [[ -f scripts/release-notes/release-notes.sh ]]; then
    rm -f scripts/release-notes/release-notes.sh
    git add scripts/release-notes/release-notes.sh
    git diff --cached --quiet || git commit -m "Remove release-notes script"
fi

cp -r "$PATCHES_DIR/lp-management-scripts" .
git add lp-management-scripts
git diff --cached --quiet || git commit -m "Add lp-management-scripts"
