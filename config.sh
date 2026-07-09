export VERSION=""
export LP_USERNAME=""
export PREFIX="lp"
export GRADLE_DIST_URL="canonical.jfrog.io/artifactory/dataplatform-generic-stable-local/gradle"
export ARTIFACTORY_URL="https://canonical.jfrog.io/artifactory/dataplatform-opensearch-staging"

export LP_SOSS_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/soss/+source"

[[ -n "$VERSION" ]] || { echo "ERROR: VERSION is not set in config.sh"; exit 1; }
[[ -n "$LP_USERNAME" ]] || { echo "ERROR: LP_USERNAME is not set in config.sh"; exit 1; }

echo "Version: ${VERSION} Branch: ${PREFIX}-${VERSION}"
echo

# git ref for opensearch-build (if version tag is missing, add specific commit here)
case "$VERSION" in
    # e.g.
    # 3.7.0) export VERSION_REF="6d305d48a5493c907b1c17aae161b9b3dbcacdf2" ;;
    *)     export VERSION_REF="$VERSION" ;;
esac
