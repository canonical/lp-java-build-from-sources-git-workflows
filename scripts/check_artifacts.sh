#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_BASE="${ROOT_DIR}/repos"
JFROG_REPO="dataplatform-generic-stable-local"
OUTPUT="${ROOT_DIR}/missing-artifacts.txt"

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
        echo "No .nvmrc found"
        return
    fi

    version=$(cat "$nvmrc" | tr -d '[:space:]')
    existing=$(jf rt search "${JFROG_REPO}/node/v${version}/*" 2>/dev/null || true)

    for artifact in "node-v${version}-linux-x64.tar.gz" "SHASUMS256.txt"; do
        if echo "$existing" | grep -q "$artifact"; then
            echo "on jfrog: v${version}/${artifact}"
        else
            echo "NOT on jfrog: node-v${version}/${artifact}"
            echo "node:v${version}:${artifact}" >> "$OUTPUT"
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
