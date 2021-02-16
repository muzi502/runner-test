#!/bin/bash
set -eo pipefail

DOCKER_HUB_URL="https://hub.docker.com/v2/repositories/library"
IMAGES_LIST="all_library_images.list"

SCRIPTS_PATH=$(cd $(dirname "${BASH_SOURCE}") && pwd -P)
cd ${SCRIPTS_PATH}

get_images_list() {
    ALL_IMAGES=""
    URL="${DOCKER_HUB_URL}/?page_size=100"
    while true ; do
        ALL_IMAGES="$(curl -sSL ${URL} | jq -r '.results[].name' | tr '\n' ' ') ${ALL_IMAGES}"
        URL="$(curl -sSL ${URL} | jq -r '.next')"
        if [ "${URL}" = "null" ]; then break; fi
    done
    : > ${IMAGES_LIST}
    for image in ${ALL_IMAGES};do
        if skopeo list-tags docker://${image} &> /dev/null; then
            skopeo list-tags docker://${image} | jq -c ".Tags" | tr -d '[]\"' \
            | tr ',' '\n' | sed "s|^|${image}:|g" >> ${IMAGES_LIST}
        fi
    done
}

get_manifests() {
    mkdir -p manifests
    IFS=$'\n'
    for image in $(cat ${IMAGES_LIST}); do
        skopeo inspect --raw docker://${image} | jq  -r '.manifests[].digest' \
        |  xargs -L1 -P8 -I % sh -c "skopeo inspect --raw docker://${image/:*/}@% > manifests/%.json"
    done
}

get_images_list
get_manifests
