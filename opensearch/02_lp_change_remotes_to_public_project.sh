#!/usr/bin/env bash

pushd ../..

if [ -z "${LP_USERNAME:-}" ]; then
    echo "Call this command as follows:"
    echo "$ LP_USERNAME=<your-launchpad-username> ./<command>"
    exit 1
fi

find . -maxdepth 1 \( -name "opensearch*" -o -name "python-*" \) -type d | awk '{print $1}' | while read -r project; do
    pushd "${project}" || exit 1

    if [[ "${project}" == *opensearch-build ]]; then
        popd || exit 1
        continue
    fi

    git remote remove launchpad
    git remote add launchpad "git+ssh://$LP_USERNAME@git.launchpad.net/~data-platform/opensearch-project-components/+git/${project#./}"

    popd || exit 1

done
