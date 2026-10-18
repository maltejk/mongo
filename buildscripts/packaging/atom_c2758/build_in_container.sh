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
docker build -t "$image" -f "$here/build-env/Dockerfile.$BUILD_CONTAINER" "$here/build-env"
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e JOBS="${JOBS:-}" \
    -v "$repo:/src" -w /src "$image" \
    "buildscripts/packaging/atom_c2758/$script" "$@"
