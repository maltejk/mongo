# MongoDB on Intel Atom C2758

The Atom C2758 (Silvermont/Avoton) has SSE4.2, AES-NI and PCLMUL but **no AVX/AVX2**.
The default x86_64 build uses `-march=sandybridge` (AVX) and therefore crashes with SIGILL.

## What changed

- `bazel/toolchains/cc/mongo_linux/mongo_linux_cc_toolchain_config.bzl`: new toolchain feature
  `x86_64_silvermont` (off by default). When enabled, `-march=silvermont -mtune=silvermont`
  replaces `-march=sandybridge -mtune=generic`.
- `.bazelrc`: `--config=atom_c2758` enables that feature.
- `src/third_party/mozjs`: the global `-mavx2` is gone. `SIMD_avx2.cpp` enables AVX2 for itself
  only (pragma); `mozilla::supports_avx2()` uses cpuid at runtime, so the code is never run on the C2758.
  Before, `-mavx2` made `MOZILLA_PRESUME_AVX2` true and the AVX2 path was taken unconditionally.
- `check_no_avx.sh`: objdump-based gate that fails if `mongod`/`mongos` contain VEX instructions
  outside the AVX2-gated mozjs functions. Run by `build_deb.sh` and the Dockerfile.

## Build .deb (Ubuntu 24.04 and 26.04)

Build on an AVX-capable host (an Atom C2758 is too slow/small for a Bazel build):

    buildscripts/packaging/atom_c2758/build_deb.sh [-v 9.1.0] [-o out]

Output: `out/ubuntu2404/*.deb`, `out/ubuntu2604/*.deb` (arch `amd64`). Needs `dpkg-dev debhelper fakeroot`
and the Python deps of `buildscripts/packager.py`.

## Docker image

Based on the official `mongo` image; only `mongod` and `mongos` are replaced.

    buildscripts/packaging/atom_c2758/build_image.sh -b mongo:8.0 -t mongo-atom-c2758:local

Pick `-b` to match the built server version.
