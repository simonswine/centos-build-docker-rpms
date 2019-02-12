#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT=$(dirname "${BASH_SOURCE}")
BUCKET_NAME=releases.tarmak.io
BUCKET_PATH="${BUCKET_NAME}/docker-hotfix/centos-7"

BUILD_IMAGE_NAME=simonswine/centos-docker-rpm-build

# cleanup pre-existing output
rm -rf "${SCRIPT_ROOT}/_output"

# ensure dockerfile is ready
docker build -t "${BUILD_IMAGE_NAME}" -f "${SCRIPT_ROOT}/Dockerfile" "${SCRIPT_ROOT}"

# create container instance
container_id=$(docker create ${BUILD_IMAGE_NAME})
cleanup_container() {
    docker rm -f "${container_id}" > /dev/null
}
trap "cleanup_container" EXIT SIGINT

# copy rpms out
docker cp "${container_id}:/src/_output/" "${SCRIPT_ROOT}"

# sign rpms
cat > "${SCRIPT_ROOT}/.rpmmacros" <<EOF
%_gpg_path ${HOME}/.gnupg
%_gpg_name Jetstack Releases <tech+releases@jetstack.io>
EOF
find "${SCRIPT_ROOT}/_output/" -name '*.rpm' | HOME=${SCRIPT_ROOT} xargs rpmsign --addsign

# recreate metadata
createrepo "${SCRIPT_ROOT}/_output/"

# sign metadata
gpg -u tech+releases@jetstack.io --armor --detach-sign "${SCRIPT_ROOT}/_output/repodata/repomd.xml"

# upload them to google
gsutil rsync -d -r "${SCRIPT_ROOT}/_output/" "gs://${BUCKET_PATH}"

echo "The repo can be configured like that:"

cat <<EOF
[jetstack-docker-hotfix]
name=Jetstack Docker Hotfix
baseurl=https://${BUCKET_PATH}
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://raw.githubusercontent.com/jetstack/airworthy/master/pkg/gnupg/jetstack-releases.asc
EOF
