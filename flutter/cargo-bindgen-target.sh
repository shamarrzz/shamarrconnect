#!/usr/bin/env bash
# cargo-ndk invokes this via CARGO, after it has set the target-specific
# bindgen clang args. bindgen 0.59 reads that variable and never falls
# through to BINDGEN_EXTRA_CLANG_ARGS. cargo-ndk fills it with a sysroot
# and an include path only. NDK r30 then rejects the bare Android triple
# that bindgen adds. A versioned --target already in those args is treated
# as explicit, so bindgen leaves it alone.
set -euo pipefail

target_arg=--target=aarch64-linux-android24
key=BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android
val="${!key:-}"
if [[ -n "$val" && "$val" != *"--target="* ]]; then
  export "${key}=${target_arg} ${val}"
fi

real=$(command -v cargo)
exec "$real" "$@"
