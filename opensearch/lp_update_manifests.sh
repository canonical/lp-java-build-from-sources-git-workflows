#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "${ROOT_DIR}/opensearch-build"

# check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: uncommitted changes in opensearch-build"
    exit 1
fi

# use separate branches for opensearch and dashbaords
if [[ "$PRODUCT" == "opensearch-dashboards" ]]; then
    git checkout -B "${PREFIX}-dashboards-${VERSION}"
else
    git checkout -B "${PREFIX}-${VERSION}"
fi

cd "${ROOT_DIR}"

MANIFEST="${ROOT_DIR}/opensearch-build/manifests/${VERSION}/${PRODUCT}-${VERSION}.yml"

if [[ "$PRODUCT" == "opensearch" ]]; then
    LP_URL="https://git.launchpad.net/~data-platform/opensearch-project-components/+git"
else
    LP_URL="https://git.launchpad.net/~data-platform/opensearch-project-dashboards-components/+git"
fi

# remove functional test component
sed -i.tmp '/- name:.*[Ff]unctionalTest/,/^  - name:/{
    /- name:.*[Ff]unctionalTest/d
    /^  - name:/!d
}' "$MANIFEST"

# replace upstream urls with launchpad's
if [[ "$PRODUCT" == "opensearch" ]]; then
    sed -i.tmp \
        -e "s|https://github\.com/opensearch-project/\([^[:space:]/]*\)\.git|${LP_URL}/opensearch-\1|g" \
        "$MANIFEST"
    # fix double opensearch- prefix and lowercase
    sed -i.tmp \
        -e "s|/opensearch-OpenSearch$|/opensearch|" \
        -e "s|/opensearch-opensearch-|/opensearch-|g" \
        "$MANIFEST"
else
    sed -i.tmp \
        -e "s|https://github\.com/opensearch-project/\([^[:space:]/]*\)\.git|${LP_URL}/\1|g" \
        "$MANIFEST"
    sed -i.tmp \
        -e "s|/OpenSearch-Dashboards$|/opensearch-dashboards|" \
        "$MANIFEST"
fi

# replace refs
sed -i.tmp \
    -e "s/ref: [a-f0-9]\{40\}/ref: tags\/${PREFIX}-v${VERSION}.0/g" \
    -e "s|ref: tags/${VERSION}.0|ref: tags/${PREFIX}-v${VERSION}.0|g" \
    -e "s|ref: tags/${VERSION}|ref: tags/${PREFIX}-v${VERSION}|g" \
    "$MANIFEST"

# set non-dotted tag for opensearch (this matches upstream but we've done it both ways, check policy)
sed -i.tmp "/- name: OpenSearch$/,/ref:/s|ref: tags/${PREFIX}-v${VERSION}.0|ref: tags/${PREFIX}-v${VERSION}|" "$MANIFEST"
sed -i.tmp "/- name: OpenSearch-Dashboards$/,/ref:/s|ref: tags/${PREFIX}-v${VERSION}.0|ref: tags/${PREFIX}-v${VERSION}|" "$MANIFEST"

# lowercase launchpad urls
awk '/git\.launchpad\.net/{$0=tolower($0)}1' "$MANIFEST" > "${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"

rm -f "${MANIFEST}.tmp"

# add prometheus-exporter
if [[ "$PRODUCT" == "opensearch" ]] && ! grep -q "prometheus-exporter" "$MANIFEST"; then
    cat >> "$MANIFEST" << EOF
  - name: prometheus-exporter
    repository: ${LP_URL}/opensearch-prometheus-exporter
    ref: tags/${PREFIX}-v${VERSION}.0
    platforms:
      - linux
      - windows
EOF
fi

cd "${ROOT_DIR}/opensearch-build"
git add "$MANIFEST"
git diff --cached --quiet || git commit -m "Update manifest for ${PRODUCT} ${VERSION}"