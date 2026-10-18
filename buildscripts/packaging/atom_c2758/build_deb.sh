#!/usr/bin/env bash
# Build MongoDB for the Intel Atom C2758 and package it as .deb for
# Ubuntu 24.04 (ubuntu2404/noble) and Ubuntu 26.04 (ubuntu2604/resolute).
#
# Usage: build_deb.sh [-v VERSION] [-o OUTDIR] [-d build_os]... [-s]
#   -v  server version (default: SERVER_VERSION from branch.env)
#   -o  output dir; .deb files land in <out>/<build_os>/ (default: <repo>/atom-c2758-out)
#   -d  build_os to package (repeatable; default: ubuntu2404 and ubuntu2604)
#   -s  skip the build, reuse the existing tarball
# Env: JOBS (scons -j), BAZEL_EXTRA / SCONS_EXTRA (extra build flags).
# Needs: dpkg-dev apt-utils debhelper fakeroot binutils gawk python3-git + the build deps
# of the server version (see build-env/ for a ready-made container).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
# shellcheck source=branch.env
source "$here/branch.env"

version="$SERVER_VERSION"
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
[[ ${#distros[@]} -gt 0 ]] || distros=(ubuntu2404 ubuntu2604)

cd "$repo"
tarball="$("$here/build_tarball.sh" $([[ $skip_build -eq 1 ]] && echo -s) -v "$version")"
echo "tarball: $tarball"

mkdir -p "$outdir"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for d in "${distros[@]}"; do
    mkdir -p "$work/$d"
    (
        cd "$repo/buildscripts"
        python3 packager.py --prefix "$work/$d" --distros "$d" -a x86_64 \
            --tarball "$tarball" -s "$version" -m HEAD
    )
    mkdir -p "$outdir/$d"
    find "$work/$d/dst" -name '*.deb' -exec cp -v {} "$outdir/$d/" \;
done
echo "Packages in $outdir"
ls -lR "$outdir"
