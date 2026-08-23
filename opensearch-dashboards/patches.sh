#!/usr/bin/env bash

PATCHES_DIR="${ROOT_DIR}/${PRODUCT}/patches"

apply_patch() {
    local patch="$1"
    local msg="${2:-Patch: $(basename "$patch")}"
    if git apply --check --reverse "$patch" 2>/dev/null; then
        echo "Patch $(basename "$patch") already applied"
        return 0
    fi

    git apply "$patch"
    git add -A
    git commit -m "$msg"
}

apply_patches() {
    local repo="$1"

    case "$repo" in
        opensearch-dashboards)
            apply_patch "$PATCHES_DIR/opensearch-dashboards.patch" "Download node from artifactory"
            ;;
        dashboards-reporting)
            apply_patch "$PATCHES_DIR/reporting.patch" "Get trained data from jfrog"
            ;;
    esac

    return 0
}
