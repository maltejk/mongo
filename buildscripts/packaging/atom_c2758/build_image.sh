#!/usr/bin/env bash
# Build the Atom C2758 docker image by installing the ubuntu2404 .deb this
# branch produces into a matching base image (see Dockerfile for why: the
# official mongo:5.0 image's base OS is too old for our binary's glibc).
# Usage: build_image.sh [-b BASE_IMAGE] [-t TAG] [-v VERSION] [-s]
#   -b  base image (default: BASE_IMAGE from branch.env)
#   -t  resulting tag (default: mongo-atom-c2758:<version>)
#   -s  skip the build, reuse the existing debs
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
# shellcheck source=branch.env
source "$here/branch.env"

base="$BASE_IMAGE"
version="$SERVER_VERSION"
tag=""
skip_build=0
while getopts "b:t:v:s" opt; do
    case "$opt" in
    b) base="$OPTARG" ;;
    t) tag="$OPTARG" ;;
    v) version="$OPTARG" ;;
    s) skip_build=1 ;;
    *) exit 2 ;;
    esac
done
[[ -n "$tag" ]] || tag="mongo-atom-c2758:$version"

cd "$repo"
"$here/build_deb.sh" $([[ $skip_build -eq 1 ]] && echo -s) -v "$version" -o "$repo/atom-c2758-out" -d ubuntu2404 >&2

docker build --platform linux/amd64 \
    -f "$here/Dockerfile" \
    --build-arg BASE_IMAGE="$base" \
    --build-context debs="$repo/atom-c2758-out/ubuntu2404" \
    -t "$tag" .
