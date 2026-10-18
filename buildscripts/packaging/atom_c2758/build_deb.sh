#!/usr/bin/env bash
# Build MongoDB for the Intel Atom C2758 and package it as .deb for
# Ubuntu 24.04 (noble) and Ubuntu 26.04 (resolute).
#
# Usage: build_deb.sh [-v VERSION] [-o OUTDIR] [-d ubuntu2404 -d ubuntu2604] [-s]
#   -v  server version (default: MONGO_VERSION from .bazelrc.target_mongo_version)
#   -o  output dir; .deb files land in <out>/<build_os>/ (default: <repo>/atom-c2758-out)
#   -d  build_os to package (repeatable; default: ubuntu2404 and ubuntu2604)
#   -s  skip the bazel build, reuse bazel-bin/dist-stripped.tgz
#
# Extra bazel flags can be passed via BAZEL_FLAGS. Needs: bazel(isk), dpkg-dev,
# debhelper, fakeroot, python3 with the repo's buildscripts requirements (GitPython).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"

version=""
outdir="$repo/atom-c2758-out"
distros=()
skip_build=0
while getopts "v:o:d:s" opt; do
    case "$opt" in
    v) version="$OPTARG" ;;
    o) outdir="$OPTARG" ;;
    d) distros+=("$OPTARG") ;;
    s) skip_build=1 ;;
    *) exit 2 ;;
    esac
done
if [[ -z "$version" ]]; then
    version="$(sed -n 's/.*MONGO_VERSION=\(.*\)$/\1/p' "$repo/.bazelrc.target_mongo_version")"
fi
if [[ ${#distros[@]} -eq 0 ]]; then
    distros=(ubuntu2404 ubuntu2604)
fi

cd "$repo"
if [[ $skip_build -eq 0 ]]; then
    # shellcheck disable=SC2086
    bazel build --config=opt --config=atom_c2758 --define=MONGO_VERSION="$version" \
        ${BAZEL_FLAGS:-} archive-dist-stripped
fi

tarball="$repo/bazel-bin/dist-stripped.tgz"
[[ -f "$tarball" ]] || { echo "missing $tarball" >&2; exit 1; }

# Verify the shipped binaries carry no AVX code.
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
tar -xzf "$tarball" -C "$check_dir"
"$here/check_no_avx.sh" "$check_dir"/mongodb-*/bin/mongod "$check_dir"/mongodb-*/bin/mongos

mkdir -p "$outdir"
work="$(mktemp -d)"
trap 'rm -rf "$check_dir" "$work"' EXIT
for d in "${distros[@]}"; do
    (
        cd "$repo/buildscripts"
        python3 packager.py --prefix "$work/$d" --distros "$d" -a x86_64 \
            --tarball "$tarball" -s "$version" -m HEAD
    )
    mkdir -p "$outdir/$d"
    find "$work/$d" -name '*.deb' -exec cp -v {} "$outdir/$d/" \;
done
echo "Packages in $outdir"
ls -lR "$outdir"
