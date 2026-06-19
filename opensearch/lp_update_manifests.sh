#!/usr/bin/env bash
set -eux

usage() {
    echo "Usage: $0 --version <version>"
    echo "  e.g. $0 --version 2.19.5"
    exit 1
}

VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
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

if [[ -z "$VERSION" ]]; then
    echo "--version is required"
    usage
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="${SCRIPT_DIR}/opensearch-repos"

PREFIX="${PREFIX:-lp}"
PATCH_NUMBER="${PATCH_NUMBER:-0}"
LP_VERSION_TAG="${PREFIX}-v${VERSION}"
LP_VERSION_TAG_DOTTED="${PREFIX}-v${VERSION}.0"
MANIFEST="${REPO_BASE}/opensearch-build/manifests/${VERSION}/opensearch-${VERSION}.yml"

if [ ! -f "$MANIFEST" ]; then
    echo "manifest not found at $MANIFEST"
    exit 1
fi

cd "${REPO_BASE}/opensearch-build"

awk '/repository:/ { print tolower($0); next } { print }' "$MANIFEST" >tmp && mv tmp "$MANIFEST"

# replace urs with launchpad
sed -i -E 's|https://github\.com/opensearch-project/([^[:space:]/]+)\.git|https://git.launchpad.net/~data-platform/opensearch-project-components/+git/opensearch-\1|g' "$MANIFEST"

# fix double prefix for openseasrch repo
sed -i 's|opensearch-opensearch|opensearch|g' "$MANIFEST"

# replace tags (some tagged manifests use a hash instead of "tags/" for some reason)
sed -i -E "s/ref: [a-f0-9]{40}/ref: tags\/${LP_VERSION_TAG_DOTTED}/g" "$MANIFEST"
sed -i "s|ref: tags/${VERSION}.0|ref: tags/${LP_VERSION_TAG_DOTTED}|g" "$MANIFEST"
sed -i "s|ref: tags/${VERSION}|ref: tags/${LP_VERSION_TAG}|g" "$MANIFEST"

# set non-dotted tag for opensearch (this matches upstream but we've done it both ways, check policy)
sed -i -E "/- name: OpenSearch$/,/ref:/{s|ref: tags/${LP_VERSION_TAG_DOTTED}|ref: tags/${LP_VERSION_TAG}|}" "$MANIFEST"

# add prometheus-exporter
if ! grep -q "prometheus-exporter" "$MANIFEST"; then
    cat >>"$MANIFEST" <<EOF
  - name: prometheus-exporter
    repository: https://git.launchpad.net/~data-platform/opensearch-project-components/+git/opensearch-prometheus-exporter-plugin-for-opensearch
    ref: tags/${LP_VERSION_TAG_DOTTED}
    platforms:
      - linux
      - windows
EOF
fi

# validate yaml
if python3 -c "import yaml; yaml.safe_load(open('$MANIFEST'))" 2>/dev/null; then
    echo ""
else
    echo "fix manifest yaml file"
    exit 1
fi

awk '
      /- name:/ { name = $3 }
      /repository:/ { repo = $2 }
      /ref:/ {
          ref = $2
          print name
          print "  repo:", repo
          print "  ref: ", ref
          print ""
      }
  ' "$MANIFEST"

STAGING_URL="https://canonical.jfrog.io/artifactory/dataplatform-opensearch-staging"

sed -i \
    -e "s/^\(\s*OPENSEARCH_VERSION:\).*/\1 ${VERSION}/" \
    -e "s/^\(\s*PATCH_NUMBER:\).*/\1 ${PATCH_NUMBER}/" \
    -e "s|^\(\s*ARTIFACTORY_URL:\).*|\1 \"${STAGING_URL}\"|" .launchpad.yaml

echo "check contents of .launchpad.yaml"
cd ${SCRIPT_DIR}