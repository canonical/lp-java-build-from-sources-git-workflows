#!/usr/bin/env bash

PATCHES_DIR="${PRODUCT_DIR}/patches"

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

    grep -q "$GRADLE_DIST_URL" "$wrapper" && return 0

    sed -i.tmp "s|services.gradle.org/distributions|${GRADLE_DIST_URL}|g" "$wrapper"
    rm -f "${wrapper}.tmp"
    git add "$wrapper"
    git commit -m "Change Gradle distro url"
}

patch_spotless() {
    local repo="$1"
    local files
    files=$(get_spotless_files "$repo")

    # return if no spotless files to patch
    [[ -z "$files" ]] && return 0
    grep -q "withP2Mirrors" $files 2>/dev/null || return 0

    for f in $files; do
        grep -q "withP2Mirrors" "$f" 2>/dev/null || continue
        sed -i.tmp 's/\.withP2Mirrors(.*))\././' "$f"
        rm -f "${f}.tmp"
        git add "$f"
    done
    git diff --cached --quiet || git commit -m "Remove broken mirror from Spotless config"
}

patch_knn() {
    if ! grep -q "git.launchpad.net" .gitmodules; then
        sed -i.tmp \
            -e 's|https://github.com/nmslib/nmslib.git|https://git.launchpad.net/~data-platform/opensearch-project-components/+git/python-nmslib|' \
            -e 's|https://github.com/facebookresearch/faiss.git|https://git.launchpad.net/~data-platform/opensearch-project-components/+git/python-faiss|' \
            .gitmodules
        rm -f .gitmodules.tmp
        sed -i.tmp "s|cut -d ' ' -f3|cut -d ' ' -f4|" scripts/build.sh && rm -f scripts/build.sh.tmp
        git add .gitmodules scripts/build.sh
        git commit -m "Change git submodules and gcc version parsing"
    fi

    if ! grep -q "aarch64" build.gradle; then
        git apply "${PATCHES_DIR}/knn.patch"
        git add build.gradle
        git commit -m "Add arm64 blas libs"
    fi
}

patch_performance_analyzer() {
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
    # check if "-snapshot" appears before if block (should be fixed in 3.4.0 but still exists in 2.19.x)
    grep -B1 'if (isSnapshot) {' build.gradle | grep -q 'alerting_spi_build += "-SNAPSHOT"' || return 0

    git apply "${PATCHES_DIR}/security-analytics.patch"
    git add build.gradle
    git diff --cached --quiet || git commit -m "Fix alerting-spi snapshot version"
}

patch_alerting() {
    grep -q "configurations.ktlint.incoming.beforeResolve" build.gradle || return 0
    grep -q "repositories.clear()" build.gradle || return 0

    git apply "${PATCHES_DIR}/alerting.patch"
    git add build.gradle
    git diff --cached --quiet || git commit -m "Fix ktlint beforeResolve"
}

patch_prometheus_exporter() {
    if grep -q "^opensearch_version.*-SNAPSHOT" gradle.properties; then
        sed -i.tmp '/^opensearch_version/s/-SNAPSHOT//' gradle.properties
        rm -f gradle.properties.tmp
        git add gradle.properties
        git commit -m "Remove snapshot from version"
    fi
    # add a publish task (3.6.0+ has this but still needed in 2.19.x)
    if ! grep -q "pluginZip(MavenPublication)" build.gradle; then
        git apply "${PATCHES_DIR}/prometheus-publishing.patch"
        git add build.gradle
        git commit -m "Add pluginZip publishing for maven local"
    fi
    # uncomment group if commented, or add it
    sed -i.tmp 's/^#group = org.opensearch.plugin.prometheus/group = org.opensearch.plugin.prometheus/' gradle.properties
    rm -f gradle.properties.tmp
    if ! grep -q "^group = org.opensearch.plugin.prometheus" gradle.properties; then
        echo "group = org.opensearch.plugin.prometheus" >> gradle.properties
    fi
    git add gradle.properties
    git diff --cached --quiet || git commit -m "Add group for maven publishing"
}

patch_reporting() {
    grep -q "git.launchpad.net" build.gradle && return 0

    # replace with lp urls
    sed -i.tmp \
        -e "s|\"https://raw.githubusercontent.com/opensearch-project/security/refs/heads/main/bwc-test/src/test/resources/security/\" + file|\"https://git.launchpad.net/~data-platform/opensearch-project-components/+git/opensearch-security/plain/bwc-test/src/test/resources/security/\${file}?h=${PREFIX}-${VERSION}\"|" \
        build.gradle
    rm -f build.gradle.tmp
    git add build.gradle
    git diff --cached --quiet || git commit -m "Replace cert download urls"
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

    # remove broken ktlint beforeResolve hook
    [[ "$repo" == "opensearch-alerting" ]] && patch_alerting

    # remove snapshot from opensearch version in prometheus-exporter
    [[ "$repo" == "opensearch-prometheus-exporter" ]] && patch_prometheus_exporter

    # replace github urls with lp urls for cert downloads
    [[ "$repo" == "opensearch-reporting" ]] && patch_reporting

    return 0
}
