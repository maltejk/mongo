#!/usr/bin/env bash
# Build the server tarball with Atom C2758 code generation, run the AVX gate
# on mongod/mongos and print the tarball path on stdout (logs go to stderr).
# Usage: build_tarball.sh [-v VERSION] [-s]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
# shellcheck source=branch.env
source "$here/branch.env"

version="$SERVER_VERSION"
skip_build=0
while getopts "v:s" opt; do
    case "$opt" in
    v) version="$OPTARG" ;;
    s) skip_build=1 ;;
    *) exit 2 ;;
    esac
done

cd "$repo"
case "$BUILD_SYSTEM" in
bazel)
    tarball="$repo/bazel-bin/dist-stripped.tgz"
    if [[ $skip_build -eq 0 ]]; then
        bazel build "${BAZEL_FLAGS[@]}" --define=MONGO_VERSION="$version" ${BAZEL_EXTRA:-} \
            archive-dist-stripped >&2
    fi
    ;;
scons)
    tarball="$repo/mongodb-dist.tgz"
    if [[ $skip_build -eq 0 ]]; then
        python3 buildscripts/scons.py -j"${JOBS:-$(nproc)}" "${SCONS_FLAGS[@]}" \
            MONGO_VERSION="$version" ${SCONS_EXTRA:-} archive-dist >&2
    fi
    ;;
*)
    echo "unknown BUILD_SYSTEM=$BUILD_SYSTEM" >&2
    exit 1
    ;;
esac
[[ -f "$tarball" ]] || { echo "missing $tarball" >&2; exit 1; }

check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
tar -xzf "$tarball" -C "$check_dir"
"$here/check_no_avx.sh" "$check_dir"/mongodb-*/bin/mongod "$check_dir"/mongodb-*/bin/mongos >&2
echo "$tarball"
