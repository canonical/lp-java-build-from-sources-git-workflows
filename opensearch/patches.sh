#!/usr/bin/env bash

get_spotless_files() {
    case "$1" in
        opensearch-learning-to-rank-base) echo "build.gradle" ;;
        opensearch-query-insights) echo "build.gradle" ;;
        opensearch-neural-search) echo "gradle/formatting.gradle" ;;
        opensearch-k-nn) echo "gradle/formatting.gradle" ;;
        opensearch-ml-commons) echo "memory/build.gradle search-processors/build.gradle ml-algorithms/build.gradle plugin/build.gradle common/build.gradle client/build.gradle" ;;
        *) echo "" ;;
    esac
}

patch_gradle() {
    local wrapper="gradle/wrapper/gradle-wrapper.properties"
    [[ -f "notifications/$wrapper" ]] && wrapper="notifications/$wrapper"
    [[ -f "$wrapper" ]] || return 0

    grep -q "$JFROG_URL" "$wrapper" && return 0

    sed -i.tmp "s|services.gradle.org/distributions|${JFROG_URL}|g" "$wrapper"
    sed -i.tmp "s|^# distributionSha256Sum|distributionSha256Sum|" "$wrapper"
    rm -f "${wrapper}.tmp"
    git add "$wrapper"
    git diff --cached --quiet || git commit -m "Change Gradle distro url"
}

patch_spotless() {
    local repo="$1"
    local files
    files=$(get_spotless_files "$repo")

    # return if no spotless files to patch
    [[ -z "$files" ]] && return 0

    for f in $files; do
        grep -q "withP2Mirrors" "$f" 2>/dev/null || continue
        sed -i.tmp 's/\.withP2Mirrors(.*))\././' "$f"
        rm -f "${f}.tmp"
        git add "$f"
    done
    git diff --cached --quiet || git commit -m "Remove broken mirror from Spotless config"
}

patch_knn() {
    grep -q "git.launchpad.net" .gitmodules && return 0

    sed -i.tmp \
        -e 's|https://github.com/nmslib/nmslib.git|https://git.launchpad.net/~data-platform/opensearch-project-components/+git/python-nmslib|' \
        -e 's|https://github.com/facebookresearch/faiss.git|https://git.launchpad.net/~data-platform/opensearch-project-components/+git/python-faiss|' \
        .gitmodules
    rm -f .gitmodules.tmp
    [[ -f "scripts/build.sh" ]] && sed -i.tmp "s|cut -d ' ' -f3|cut -d ' ' -f4|" scripts/build.sh && rm -f scripts/build.sh.tmp
    git add .gitmodules scripts/build.sh 2>/dev/null || true
    git diff --cached --quiet || git commit -m "Change git submodules and gcc version parsing"
}

patch_performance_analyzer() {
    [[ -f "build.gradle" ]] && grep -q "performance-analyzer-rca" build.gradle || return 0

    grep -q "git.launchpad.net" build.gradle && return 0

    BRANCH="${PREFIX}-${VERSION}"
    sed -i.tmp \
        -e 's|https://github.com/opensearch-project/performance-analyzer-rca.git|git://git.launchpad.net/~data-platform/opensearch-project-components/+git/opensearch-performance-analyzer-rca|' \
        -e "s|\${rcaProjectFetch}/2.x|\${rcaProjectFetch}/${BRANCH}|" \
        -e "s|\${rcaProjectFetch}/main|\${rcaProjectFetch}/${BRANCH}|" \
        build.gradle
    rm -f build.gradle.tmp
    git add build.gradle
    git diff --cached --quiet || git commit -m "Update LP remote RCA"
}

patch_security_analytics() {
    [[ -f "build.gradle" ]] || return 0
    grep -q 'alerting_spi_build += "-SNAPSHOT"' build.gradle || return 0
    grep -q '// alerting_spi_build += "-SNAPSHOT"' build.gradle && return 0

    sed -i.tmp 's|alerting_spi_build += "-SNAPSHOT"|// alerting_spi_build += "-SNAPSHOT"|' build.gradle
    sed -i.tmp 's|if (isSnapshot) {|if (isSnapshot) {\
            alerting_spi_build += "-SNAPSHOT"|' build.gradle
    rm -f build.gradle.tmp
    git add build.gradle
    git diff --cached --quiet || git commit -m "Fix alerting-spi snapshot version"
}

apply_patches() {
    local repo="$1"

    # patch all gradle distro urls
    patch_gradle

    # if version 2.x, apply spotless patches
    case "$VERSION" in 2*) patch_spotless "$repo" ;; esac

    # apply k-nn patch
    [[ "$repo" == "opensearch-k-nn" ]] && patch_knn

    # apply performance analyzer patch
    [[ "$repo" == "opensearch-performance-analyzer" ]] && patch_performance_analyzer

    # fix alerting-spi snapshot version
    [[ "$repo" == "opensearch-security-analytics" ]] && patch_security_analytics

    return 0
}
