# MongoDB for Intel Atom C2758, built from the .deb this branch produces for
# Ubuntu 24.04 (noble) and installed into a matching base image.
#
# The official mongo:<series> image's base OS can be older than the Ubuntu
# 22.04 build container these binaries are linked against (confirmed on
# 5.0: mongo:5.0 is Ubuntu 20.04/glibc 2.31, too old for glibc >= 2.34).
# Installing the .deb into an ubuntu:24.04 base avoids any such ABI
# mismatch, and the deb's postinst creates the mongodb user and
# /var/lib/mongodb, /var/log/mongodb for us.
#
# Use buildscripts/packaging/atom_c2758/build_image.sh; it builds the debs
# and passes the ubuntu2404 output dir as build context "debs".

ARG BASE_IMAGE=ubuntu:24.04

FROM ${BASE_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive
COPY --from=debs mongodb-org-server_*.deb mongodb-org-mongos_*.deb /tmp/debs/
RUN apt-get update \
    && apt-get install -y --no-install-recommends /tmp/debs/*.deb \
    && rm -rf /tmp/debs /var/lib/apt/lists/*
LABEL org.opencontainers.image.description="MongoDB built for Intel Atom C2758 (no AVX)"
VOLUME /var/lib/mongodb
EXPOSE 27017
USER mongodb
ENTRYPOINT ["mongod", "--bind_ip_all", "--dbpath", "/var/lib/mongodb"]
