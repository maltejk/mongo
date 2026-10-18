# MongoDB 9.0.4 on Intel Atom C2758

The Atom C2758 (Silvermont/Avoton) has SSE4.2 and PCLMUL but **no AVX/AVX2**. Upstream builds of the
5.0+ series use `-march=sandybridge` (AVX) and crash with SIGILL on it.

This branch: `atom-c2758/9.0`, based on the upstream tag for 9.0.4, build system `bazel`,
build container `ubuntu24.04`, official base image `mongo:9.0`. See `CHANGES` below for what differs from
the tag. Nothing here has been built or run on a C2758 unless stated in the project notes.

## Use

Run on an AVX-capable x86_64 host with docker (the C2758 is too weak to build):

    buildscripts/packaging/atom_c2758/build_in_container.sh                    # .deb for ubuntu2404 + ubuntu2604
    buildscripts/packaging/atom_c2758/build_in_container.sh build_image.sh     # docker image on top of mongo:9.0

Output: `atom-c2758-out/<build_os>/*.deb` (amd64). Without docker: run `build_deb.sh` / `build_image.sh`
directly on a host that has the build dependencies of this server version (see `build-env/`).
`check_no_avx.sh` runs automatically on `mongod`/`mongos`; it fails on VEX (AVX) instructions
outside the runtime-dispatched mozjs AVX2 routines.

Run on the C2758 itself: `mongod --version`, `grep -c -w avx /proc/cpuinfo` must print 0, then an insert/find test.

## Changes against the upstream tag

- `bazel/toolchains/cc/mongo_linux/mongo_linux_cc_toolchain_config.bzl`: toolchain feature `x86_64_silvermont` (off by default) switches `-march=sandybridge` to `-march=silvermont -mtune=silvermont`; `--config=atom_c2758` in `.bazelrc` enables it.
- `src/third_party/mozjs/BUILD.bazel`: global `-mavx2` removed (it made `MOZILLA_PRESUME_AVX2` true, bypassing the cpuid check). `extract/mozglue/misc/SIMD_avx2.cpp` enables AVX2 for itself only via pragma; the runtime dispatch in `SIMD.cpp` decides.
- `.bazelversion` 7.5.0-mongo_90b8a7b6611912 from the tag. Untested build.
- `buildscripts/packager.py` already knows `ubuntu2404` and `ubuntu2604` in this tag; no change.
