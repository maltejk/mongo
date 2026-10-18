# MongoDB for Intel Atom C2758, layered on the official mongo image.
#
# The official image ships mongod/mongos built for AVX-capable CPUs (sandybridge
# baseline) which crash with SIGILL on the C2758. This image keeps everything
# else from the official image (entrypoint, user, volumes, mongosh) and swaps
# in binaries built with --config=atom_c2758.
#
# Build (from the repo root, after `bazel build --config=opt --config=atom_c2758 archive-dist-stripped`):
#   docker build -f buildscripts/packaging/atom_c2758/Dockerfile \
#     --build-arg BASE_IMAGE=mongo:8.0 \
#     --build-context dist=bazel-bin -t mongo-atom-c2758:local .
# or use buildscripts/packaging/atom_c2758/build_image.sh.

ARG BASE_IMAGE=mongo:8.0

FROM ubuntu:24.04 AS extract
RUN apt-get update && apt-get install -y --no-install-recommends binutils gawk \
    && rm -rf /var/lib/apt/lists/*
COPY --from=dist dist-stripped.tgz /tmp/dist-stripped.tgz
COPY buildscripts/packaging/atom_c2758/check_no_avx.sh /usr/local/bin/check_no_avx.sh
RUN mkdir /dist && tar -xzf /tmp/dist-stripped.tgz -C /dist --strip-components=1 \
    && check_no_avx.sh /dist/bin/mongod /dist/bin/mongos

FROM ${BASE_IMAGE}
COPY --from=extract /dist/bin/mongod /usr/bin/mongod
COPY --from=extract /dist/bin/mongos /usr/bin/mongos
LABEL org.opencontainers.image.description="MongoDB built for Intel Atom C2758 (no AVX)" \
      org.opencontainers.image.base.name="${BASE_IMAGE}"
