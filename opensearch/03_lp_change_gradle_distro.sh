#!/usr/bin/env bash

declare -a VERSIONS=("2.14.0")

pushd ../..

remote_url="distributionUrl=https\\\:\/\/services.gradle.org\/distributions"
jfrog_url="distributionUrl=https\\\:\/\/canonical.jfrog.io\/artifactory\/dataplatform-generic-stable-local\/gradle"

find . -maxdepth 1 -name "opensearch*" -type d | awk '{print $1}' | while read -r project; do
    pushd "${project}" || exit 1

    if [[ "${project}" == *python ]]; then
        continue
    fi

    if [[ "${project}" == *opensearch-performance-analyzer-rca ]]; then
        git checkout main
        sed -i -e "s/^${remote_url}\+/${jfrog_url}/g" gradle/wrapper/gradle-wrapper.properties
        git add .
        git commit -m "changed gradle distro url"
        git push launchpad

        popd || exit 1
        continue
    fi

    if [[ "${project}" == *opensearch-build ]]; then
        # opensearch build needs more than just gradle distro update:
        # This commit is pulled:
        # https://git.launchpad.net/soss/+source/opensearch-build/commit/?h=lp-2.14.0&id=c15653f10ff00437e4fd62ac2cc455aef597731e
        original_branch="$(git branch --show-current)"
        git checkout lp-2.14.0
        git switch "${original_branch}"

        # Needed because we need to add several files, such as .launchpad.yaml
        git cherry-pick c15653f10ff00437e4fd62ac2cc455aef597731e
        git push launchpad

        popd || exit 1
        continue
    fi

    if [[ "${project}" == *opensearch-prometheus-exporter-plugin-for-opensearch ]]; then
        # prometheus exporter needs some extra scripts to make it work with OpenSearch build mechanism
        # So, besides the gradle-wrapper.properties, we also need some extra information.
        # Pull it from another branch:
        original_branch="$(git branch --show-current)"
        git checkout lp-2.13.0
        git switch "${original_branch}"

        # Pull the following commit:
        # https://git.launchpad.net/~data-platform/opensearch-project-components/+git/opensearch-prometheus-exporter-plugin-for-opensearch/commit/?h=lp-2.11.1&id=6d71f243367f7e28e6262d929122134c2259499c
        # That adds the build scripts to sync prometheus-exporter with remainder of opensearch build process
        git cherry-pick 6d71f243367f7e28e6262d929122134c2259499c
        git push launchpad

        popd || exit 1
        continue
    fi

    for version in "${VERSIONS[@]}"; do
        git checkout "lp-${version}"

        gradle_wrapper="gradle/wrapper/gradle-wrapper.properties"
        if [[ "${project}" == *notifications* ]]; then
            gradle_wrapper="notifications/${gradle_wrapper}"
        fi

        sed -i -e "s/^${remote_url}\+/${jfrog_url}/g" "${gradle_wrapper}"
        sed -i -e "s/^# distributionSha256Sum\+/distributionSha256Sum/g" "${gradle_wrapper}"

        git add .
        git commit -m "changed gradle distro url"
        git push launchpad

        version_tag="$(git tag -l --sort=version:refname "lp-v${version}.*" | tail -1)"
        git tag "${version_tag}" --force
        git push launchpad "${version_tag}" --force

    done

    popd || exit 1

done
