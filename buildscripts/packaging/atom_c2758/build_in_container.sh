#!/usr/bin/env bash
# Run build_deb.sh (or another script) inside the version-specific build container.
# Usage: build_in_container.sh [script] [args...]    (default script: build_deb.sh)
# The repo is bind-mounted at /src; output ends up in the repo (atom-c2758-out/).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
# shellcheck source=branch.env
source "$here/branch.env"

script="${1:-build_deb.sh}"
[[ $# -gt 0 ]] && shift
image="atom-c2758-build:$BUILD_CONTAINER"
docker build -t "$image" -f "$here/build-env/Dockerfile.$BUILD_CONTAINER" "$repo"
# Rootless podman remaps uids in a user namespace by default, which breaks the
# bind-mounted repo's ownership for -u <host-uid>; --userns=keep-id keeps a 1:1
# mapping. Real docker doesn't have (or need) this flag.
userns_flag=()
docker --version 2>/dev/null | grep -qi podman && userns_flag=(--userns=keep-id)
docker run --rm -u "$(id -u):$(id -g)" "${userns_flag[@]}" -e HOME=/tmp -e JOBS="${JOBS:-}" \
    -v "$repo:/src" -w /src "$image" \
    "buildscripts/packaging/atom_c2758/$script" "$@"
