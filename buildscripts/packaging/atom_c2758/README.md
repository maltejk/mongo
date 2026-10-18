# MongoDB 4.4.31 on Intel Atom C2758

The Atom C2758 (Silvermont/Avoton) has SSE4.2 and PCLMUL but **no AVX/AVX2**. Upstream builds of the
5.0+ series use `-march=sandybridge` (AVX) and crash with SIGILL on it.

This branch: `atom-c2758/4.4`, based on the upstream tag for 4.4.31, build system `scons`,
build container `ubuntu20.04-openssl111`, official base image `mongo:4.4`. See `CHANGES` below for what differs from
the tag. Nothing here has been built or run on a C2758 unless stated in the project notes.

## Use

Run on an AVX-capable x86_64 host with docker (the C2758 is too weak to build):

    buildscripts/packaging/atom_c2758/build_in_container.sh                    # .deb for ubuntu2404 + ubuntu2604
    buildscripts/packaging/atom_c2758/build_in_container.sh build_image.sh     # docker image on top of mongo:4.4

Output: `atom-c2758-out/<build_os>/*.deb` (amd64). Without docker: run `build_deb.sh` / `build_image.sh`
directly on a host that has the build dependencies of this server version (see `build-env/`).
`check_no_avx.sh` runs automatically on `mongod`/`mongos`; it fails on VEX (AVX) instructions
outside the runtime-dispatched mozjs AVX2 routines.

Run on the C2758 itself: `mongod --version`, `grep -c -w avx /proc/cpuinfo` must print 0, then an insert/find test.

## Changes against the upstream tag

- No code generation change: 4.4 has no `-march=sandybridge` default and no AVX2 in mozjs; the stock x86_64 baseline already runs on the C2758.
- Build container `build-env/Dockerfile.ubuntu20.04-openssl111` builds OpenSSL 1.1.1w static (sha256 checked), because 4.4 has no OpenSSL 3 support and the binaries must not depend on `libssl1.1` (absent on Ubuntu 24.04/26.04). **Not built or tested**: static linking via `CPPPATH`/`LIBPATH` and gcc-9 with the 4.4 tree are untested.
- `buildscripts/packager.py`: `ubuntu2404` (noble) and `ubuntu2604` (resolute) added where missing. Tested with a dummy tarball (real `dpkg-buildpackage`), not with a real server build.
