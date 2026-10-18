#!/usr/bin/env bash
# Build the Atom C2758 docker image on top of the official mongo image.
# Usage: build_image.sh [-b BASE_IMAGE] [-t TAG] [-s]
#   -b  official base image (default mongo:8.0)
#   -t  resulting tag (default mongo-atom-c2758:local)
#   -s  skip the bazel build, reuse bazel-bin/dist-stripped.tgz
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
base="mongo:8.0"
tag="mongo-atom-c2758:local"
skip_build=0
while getopts "b:t:s" opt; do
    case "$opt" in
    b) base="$OPTARG" ;;
    t) tag="$OPTARG" ;;
    s) skip_build=1 ;;
    *) exit 2 ;;
    esac
done

cd "$repo"
if [[ $skip_build -eq 0 ]]; then
    # shellcheck disable=SC2086
    bazel build --config=opt --config=atom_c2758 ${BAZEL_FLAGS:-} archive-dist-stripped
fi

# bazel-bin is a symlink; resolve it so the build context is a real directory.
docker build --platform linux/amd64 \
    -f buildscripts/packaging/atom_c2758/Dockerfile \
    --build-arg BASE_IMAGE="$base" \
    --build-context dist="$(readlink -f bazel-bin)" \
    -t "$tag" .
