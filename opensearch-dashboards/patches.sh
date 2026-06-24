#!/usr/bin/env bash

PATCHES_DIR="${PRODUCT_DIR}/patches"

apply_patches() {
    local repo="$1"

    case "$repo" in
        opensearch-dashboards)
            case "$VERSION" in
                2*) git am --3way "$PATCHES_DIR/opensearch-dashboards-2.x.patch" ;;
                *)  git am --3way "$PATCHES_DIR/opensearch-dashboards-3.x.patch" ;;
            esac
            ;;
        dashboards-reporting)
            git am --3way "$PATCHES_DIR/dashboards-reporting.patch"
            ;;
    esac

    return 0
}
