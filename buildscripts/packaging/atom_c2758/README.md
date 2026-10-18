# MongoDB 8.2.12 on Intel Atom C2758

The Atom C2758 (Silvermont/Avoton) has SSE4.2 and PCLMUL but **no AVX/AVX2**. Upstream builds of the
5.0+ series use `-march=sandybridge` (AVX) and crash with SIGILL on it.

This branch: `atom-c2758/8.2`, based on the upstream tag for 8.2.12, build system `bazel`,
build container `ubuntu24.04`, official base image `mongo:8.2`. See `CHANGES` below for what differs from
the tag. Nothing here has been built or run on a C2758 unless stated in the project notes.

## Use

Run on an AVX-capable x86_64 host with docker (the C2758 is too weak to build):

    buildscripts/packaging/atom_c2758/build_in_container.sh                    # .deb for ubuntu2404 + ubuntu2604
    buildscripts/packaging/atom_c2758/build_in_container.sh build_image.sh     # docker image on top of mongo:8.2

Output: `atom-c2758-out/<build_os>/*.deb` (amd64). Without docker: run `build_deb.sh` / `build_image.sh`
directly on a host that has the build dependencies of this server version (see `build-env/`).
`check_no_avx.sh` runs automatically on `mongod`/`mongos`; it fails on VEX (AVX) instructions
outside the runtime-dispatched mozjs AVX2 routines.

Run on the C2758 itself: `mongod --version`, `grep -c -w avx /proc/cpuinfo` must print 0, then an insert/find test.

## Changes against the upstream tag

- `bazel/toolchains/cc/mongo_linux/mongo_compiler_flags.bzl`: x86_64 `-march=sandybridge -mtune=generic` replaced by `-march=silvermont -mtune=silvermont` unconditionally (this branch is Atom-only).
- `src/third_party/mozjs/BUILD.bazel`: global `-mavx2` removed (it made `MOZILLA_PRESUME_AVX2` true, bypassing the cpuid check). `extract/mozglue/misc/SIMD_avx2.cpp` enables AVX2 for itself only via pragma; the runtime dispatch in `SIMD.cpp` decides.
- `src/third_party/aws-sdk` (aws-c-common, aws-checksums) is compiled with `-mavx -mavx2 -mavx512*`, but is only reached via librdkafka's `aws-cjson`, which has no AVX flags. If a streams/enterprise target links the other aws libs, they must be fixed too; `check_no_avx.sh` will catch it.
- `branch.env` builds with `--config=opt`; target and `.bazelversion` from the tag. Untested build.
- `buildscripts/packager.py`: `ubuntu2404` (noble) and `ubuntu2604` (resolute) added where missing. Tested with a dummy tarball (real `dpkg-buildpackage`), not with a real server build.
