#!/usr/bin/env bash
# Build the Atom C2758 docker image on top of the official mongo image.
# Usage: build_image.sh [-b BASE_IMAGE] [-t TAG] [-v VERSION] [-s]
#   -b  official base image (default: BASE_IMAGE from branch.env)
#   -t  resulting tag (default: mongo-atom-c2758:<version>)
#   -s  skip the build, reuse the existing tarball
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
tarball="$("$here/build_tarball.sh" $([[ $skip_build -eq 1 ]] && echo -s) -v "$version")"

# Dedicated, real directory as build context for the tarball.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp "$tarball" "$stage/dist.tgz"
docker build --platform linux/amd64 \
    -f buildscripts/packaging/atom_c2758/Dockerfile \
    --build-arg BASE_IMAGE="$base" \
    --build-context dist="$stage" \
    -t "$tag" .
