#!/bin/bash

org='aquasecurity'
proj='trivy'
version_number=10

versions(){
    curl -sL "https://api.github.com/repos/${org}/${proj}/tags" | jq -r ".[].name" | \
        sort -rV | \
        head -n ${version_number} | \
        sort -V
}

batch_build() {
    local versions_=$(versions)

    for version_ in $versions_; do
        ./scripts/build_in_docker.sh $version_
    done

}

batch_upload() { 

    local versions_=$(versions)

    for version_ in $versions_; do
        gh release view ${version_} > /dev/null 2>&1 || ./scripts/release.sh $version_ 'loongarch64'
    done

}

batch_upload
