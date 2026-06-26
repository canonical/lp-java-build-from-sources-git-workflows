#!/usr/bin/env bash

PATCHES_DIR="${PRODUCT_DIR}/patches"

apply_patches() {
    local repo="$1"

    git am --abort 2>/dev/null || true

    case "$repo" in
        opensearch-dashboards)
            grep -q "ARTIFACTORY_URL" src/dev/build/tasks/nodejs/node_download_info.ts && return 0

            case "$VERSION" in
                2*) git am --3way "$PATCHES_DIR/opensearch-dashboards-2.x.patch" ;;
                *)  git am --3way "$PATCHES_DIR/opensearch-dashboards-3.x.patch" ;;
            esac
            ;;
        dashboards-reporting)
            grep -q "canonical.jfrog.io" scripts/postinstall.js 2>/dev/null && return 0

            git am --3way "$PATCHES_DIR/dashboards-reporting.patch"
            ;;
    esac

    return 0
}
