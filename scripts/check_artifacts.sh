#!/usr/bin/env bash
set -eu

command -v jf >/dev/null || { echo "jf is required. See https://jfrog.com/getcli/"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_BASE="${ROOT_DIR}/repos"
JFROG_REPO="dataplatform-generic-stable-local"
OUTPUT="${ROOT_DIR}/artifacts/missing.txt"

mkdir -p "${ROOT_DIR}/artifacts"
: > "$OUTPUT"

check_gradle() {
    echo "Checking gradle artifacts..."

    if [[ ! -d "$REPO_BASE/opensearch" ]] || [[ -z "$(ls -A "$REPO_BASE/opensearch")" ]]; then
        echo "No repos found. Run opensearch:clone"
        return
    fi

    existing=$(jf rt search "${JFROG_REPO}/gradle/gradle-*.zip" 2>/dev/null || true)

    for repo in "$REPO_BASE"/opensearch/*; do
        [[ -d "$repo" ]] || continue
        repo_name=$(basename "$repo")

        wrapper="$repo/gradle/wrapper/gradle-wrapper.properties"
        [[ -f "$wrapper" ]] || wrapper="$repo/notifications/gradle/wrapper/gradle-wrapper.properties"
        [[ -f "$wrapper" ]] || continue

        url=$(grep -E "^distributionUrl=" "$wrapper" | cut -d= -f2- | sed 's/\\:/:/g')
        [[ -n "$url" ]] || continue

        artifact=$(basename "$url")
        if ! echo "$existing" | grep -q "$artifact"; then
            echo "NOT on jfrog: $artifact ($repo_name)"
            echo "gradle:${artifact}" >> "$OUTPUT"
        fi
    done
}

check_node() {
    echo ""
    echo "Checking node artifact..."

    nvmrc="$REPO_BASE/opensearch-dashboards/opensearch-dashboards/.nvmrc"
    if [[ ! -f "$nvmrc" ]]; then
        echo "No .nvmrc found for opensearch-dashboards"
        return
    fi

    version=$(cat "$nvmrc" | tr -d '[:space:]')
    existing=$(jf rt search "${JFROG_REPO}/node/v${version}/*" 2>/dev/null || true)

    for arch in x64 arm64; do
        tarball="node-v${version}-linux-${arch}.tar.gz"
        if ! echo "$existing" | grep -q "$tarball"; then
            echo "NOT on jfrog: node-v${version}/${tarball}"
            echo "node:v${version}:${tarball}" >> "$OUTPUT"
        fi
    done
}

check_gradle
check_node

sort -u "$OUTPUT" -o "$OUTPUT"

if [[ -s "$OUTPUT" ]]; then
    echo ""
    echo "Missing artifacts written to missing-artifacts.txt"
else
    echo ""
    echo "No missing artifacts found."
fi
