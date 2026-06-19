#!/usr/bin/env bash
set -eu

PREFIX="${PREFIX:-lp}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="${SCRIPT_DIR}/opensearch-repos"

declare -a VERSIONS=("2.19.5")

declare -A SPOTLESS_FILES=(
    ["opensearch-learning-to-rank-base"]="build.gradle"
    ["opensearch-query-insights"]="build.gradle"
    ["opensearch-neural-search"]="gradle/formatting.gradle"
    ["opensearch-k-nn"]="gradle/formatting.gradle"
    ["opensearch-ml-commons"]="memory/build.gradle search-processors/build.gradle ml-algorithms/build.gradle plugin/build.gradle common/build.gradle
  client/build.gradle"
)

for repo in "${!SPOTLESS_FILES[@]}"; do
    project="${REPO_BASE}/${repo}"
    [[ -d "$project" ]] || continue
    cd "${project}" || exit 1

    echo "**** ${repo} ****"

    for version in "${VERSIONS[@]}"; do
        if git rev-parse --verify "${PREFIX}-${version}" >/dev/null 2>&1; then
            git checkout "${PREFIX}-${version}"
        else
            echo "branch ${PREFIX}-${version} not found in ${repo}, skipping"
            continue
        fi

        changed=false
        for spotless_file in ${SPOTLESS_FILES[$repo]}; do
            if [[ -f "${spotless_file}" ]]; then
                # remove withP2Mirrors call, keep just eclipse().configFile
                if grep -q "withP2Mirrors" "${spotless_file}"; then
                    sed -i 's/eclipse()\.withP2Mirrors(Map\.of("https:\/\/download\.eclipse\.org\/", "https:\/\/mirror\.umd\.edu\/eclipse\/"))\./eclipse()./g' "${spotless_file}"
                    git add "${spotless_file}"
                    changed=true
                fi
            fi
        done

        if [[ "$changed" == true ]] && ! git diff --cached --quiet; then
            git commit -m "remove broken mirror from spotless config"
            echo "committed spotless fix in ${repo}"
        else
            echo "no change applied"
            echo ""
        fi

        version_tag="$(git tag -l --sort=version:refname "${PREFIX}-v${version}*" | tail -1)"

        echo "${repo} to branch ${PREFIX}-${version}, tag ${version_tag}"
        read -p "Push to launchpad? [y/N] " -n 1 -r
        [[ $REPLY =~ ^[Yy]$ ]] || {
            echo "aborted"
            echo ""
            continue
        }
        git push launchpad "${PREFIX}-${version}"
        git push launchpad --delete "${version_tag}" 2>/dev/null || true
        git push launchpad "${version_tag}"
    done
done