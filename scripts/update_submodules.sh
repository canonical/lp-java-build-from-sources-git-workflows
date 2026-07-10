#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/config.sh"

REPO_BASE="${ROOT_DIR}/repos/opensearch-submodules"
LP_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/~data-platform/opensearch-project-components/+git"

REPOS=(
    "https://github.com/facebookresearch/faiss.git"
    "https://github.com/nmslib/nmslib.git"
)

mkdir -p "$REPO_BASE"

for repo in "${REPOS[@]}"; do
    repo_name=$(basename "$repo" .git)
    local_name="python-${repo_name}"
    branch="main"
    [[ "$repo_name" == "nmslib" ]] && branch="master"

    echo
    echo "$local_name"
    cd "$REPO_BASE"

    if [[ ! -d "$local_name" ]]; then
        echo "Cloning into '$local_name'..."
        git clone -q "$repo" "$local_name"
    fi

    cd "$local_name"

    git fetch -q origin "$branch"
    git checkout -q "$branch"
    git reset -q --hard "origin/$branch"

    git remote remove launchpad 2>/dev/null || true
    git remote add launchpad "${LP_REMOTE}/${local_name}"

    local_head=$(git rev-parse HEAD)
    remote_head=$(git ls-remote launchpad "refs/heads/$branch" 2>/dev/null | cut -f1 || echo "")

    if [[ "$local_head" == "$remote_head" ]]; then
        echo "Already up to date."
        continue
    fi

    echo "Pushing branch '$branch' to launchpad..."
    git push launchpad "$branch" --force
done
