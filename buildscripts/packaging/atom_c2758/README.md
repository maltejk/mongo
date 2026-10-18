# MongoDB on Intel Atom C2758

The Atom C2758 (Silvermont/Avoton) has SSE4.2 and PCLMUL but **no AVX/AVX2**. (AES-NI is a CPU feature, but `gcc -march=silvermont` does not enable it; code that needs it must detect it at runtime.)
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

## Build .deb (Ubuntu 24.04 and 26.04) and docker image

Run on an AVX-capable x86_64 host with docker (the C2758 is too weak to build):

    buildscripts/packaging/atom_c2758/build_in_container.sh                   # .deb for ubuntu2404 + ubuntu2604
    buildscripts/packaging/atom_c2758/build_in_container.sh build_image.sh    # docker image on the official mongo image

Output: `atom-c2758-out/<build_os>/*.deb` (amd64). Per-version settings (build system, flags, container, base image)
are in `branch.env`; the same scripts are used on the `atom-c2758/<series>` branches for 4.4, 5.0, 6.0, 7.0, 8.0, 8.2, 8.3, 9.0.
`check_no_avx.sh` runs automatically on `mongod`/`mongos`.
