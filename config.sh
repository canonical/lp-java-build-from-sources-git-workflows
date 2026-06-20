export LAST_VERSION="2.19.4"
export VERSION="2.19.5"
export LP_USERNAME=""
export PREFIX="lp"
export JFROG_URL="canonical.jfrog.io/artifactory/dataplatform-generic-stable-local/gradle"

export LP_SOSS_REMOTE="git+ssh://${LP_USERNAME}@git.launchpad.net/soss/+source"

[[ -n "$VERSION" ]] || { echo "ERROR: VERSION is not set in config.sh"; exit 1; }
[[ -n "$LP_USERNAME" ]] || { echo "ERROR: LP_USERNAME is not set in config.sh"; exit 1; }

echo "Version: ${VERSION} Branch: ${PREFIX}-${VERSION}"
echo
