#!/usr/bin/env bash
# Fails if a binary contains AVX/AVX2 (VEX-encoded) instructions outside the
# runtime-dispatched mozjs AVX2 routines, i.e. code that would SIGILL on an
# Atom C2758 (Silvermont, no AVX).
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <elf> [<elf>...]" >&2
    exit 2
fi

rc=0
for bin in "$@"; do
    # Allowed: functions gated by mozilla::supports_avx2() (SIMD_avx2.cpp).
    offenders=$(objdump -d --no-show-raw-insn -C "$bin" | awk '
        /^[0-9a-f]+ <.*>:$/ { fn = $0; next }
        $2 ~ /^v[a-z0-9]+/ && $2 !~ /^(verr|verw|vmcall|vmclear|vmlaunch|vmptrld|vmptrst|vmread|vmresume|vmwrite|vmxoff|vmxon|vmmcall|vmload|vmrun|vmsave)/ {
            if (fn !~ /AVX2|mozilla::(Cast256|GetAs|AlignDown32|AlignUp32|CmpEq|Load64Bits|Check4x)/) bad[fn]++
        }
        END { for (f in bad) print bad[f], f }
    ' | sort -rn | head -20)
    if [[ -n "$offenders" ]]; then
        echo "FAIL: $bin contains AVX instructions outside AVX2-gated code:" >&2
        echo "$offenders" >&2
        rc=1
    else
        echo "OK: $bin has no ungated AVX instructions"
    fi
done
exit $rc
