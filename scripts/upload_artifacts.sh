#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INPUT="${ROOT_DIR}/missing-artifacts.txt"
REPO="dataplatform-generic-stable-local"
CACHE_DIR="${ROOT_DIR}/.artifact-cache"

if [[ ! -s "$INPUT" ]]; then
    echo "No missing artifacts to upload"
    exit 0
fi

echo "Missing artifacts:"
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    echo "  $line"
done < "$INPUT"

echo ""
read -p "Download all? [y/N] " confirm
[[ "$confirm" == "y" || "$confirm" == "Y" ]] || exit 0

mkdir -p "$CACHE_DIR"

verify_checksum() {
    local artifact="$1"
    local expected="$2"

    checksum=$(shasum -a 256 "${CACHE_DIR}/${artifact}" | cut -d' ' -f1)
    if [[ "$expected" != "$checksum" ]]; then
        echo "ERROR: checksum mismatch for $artifact"
        echo "  expected: $expected"
        echo "  found:   $checksum"
        rm -f "${CACHE_DIR}/${artifact}"
        return 1
    fi
    echo "checksum ok"
}

verified=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue

    type=$(echo "$line" | cut -d: -f1)

    if [[ "$type" == "gradle" ]]; then
        artifact=$(echo "$line" | cut -d: -f2)
        source_url="https://services.gradle.org/distributions/${artifact}"
    elif [[ "$type" == "node" ]]; then
        version=$(echo "$line" | cut -d: -f2)
        artifact=$(echo "$line" | cut -d: -f3)
        source_url="https://nodejs.org/dist/${version}/${artifact}"
    else
        continue
    fi

    echo ""
    echo "[$artifact]"

    if [[ -f "${CACHE_DIR}/${artifact}" ]]; then
        echo "Using cached file"
    else
        echo "Downloading..."
        curl -f# -L -o "${CACHE_DIR}/${artifact}" "$source_url"
    fi

    if [[ "$type" == "gradle" ]]; then
        expected=$(curl -fsSL "${source_url}.sha256")
        verify_checksum "$artifact" "$expected" || continue
    elif [[ "$type" == "node" ]]; then
        curl -fsSL "https://nodejs.org/dist/${version}/SHASUMS256.txt" -o "${CACHE_DIR}/SHASUMS256.txt"
        expected=$(grep "$artifact" "${CACHE_DIR}/SHASUMS256.txt" | cut -d' ' -f1)
        verify_checksum "$artifact" "$expected" || continue
        verified+=("node:${version}:SHASUMS256.txt")
    fi

    verified+=("$line")
done < "$INPUT"

if [[ ${#verified[@]} -eq 0 ]]; then
    echo "No verified artifacts to upload"
    exit 1
fi

for item in "${verified[@]}"; do
    echo "  $item"
done
echo ""

read -p "Upload all to Artifactory? [y/N] " confirm
[[ "$confirm" == "y" || "$confirm" == "Y" ]] || exit 0

# upload to artifactory
for line in "${verified[@]}"; do

    type=$(echo "$line" | cut -d: -f1)

    if [[ "$type" == "gradle" ]]; then
        artifact=$(echo "$line" | cut -d: -f2)
        target_path="${REPO}/gradle/${artifact}"
    elif [[ "$type" == "node" ]]; then
        version=$(echo "$line" | cut -d: -f2)
        artifact=$(echo "$line" | cut -d: -f3)
        target_path="${REPO}/node/${version}/${artifact}"
    fi

    echo "Uploading ${artifact} to ${target_path}..."
    jf rt upload "${CACHE_DIR}/${artifact}" "$target_path"
done

echo "Done"
