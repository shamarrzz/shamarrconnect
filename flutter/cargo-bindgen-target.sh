#!/usr/bin/env bash
# cargo-ndk invokes this via CARGO, after it has set the target-specific
# bindgen clang args. bindgen 0.59 reads that variable and never falls
# through to BINDGEN_EXTRA_CLANG_ARGS. cargo-ndk 4.1.2 fills it with a
# sysroot and an include path only. NDK r30 then rejects the bare Android
# triple that bindgen adds. A versioned --target already in those args is
# treated as explicit, so bindgen leaves it alone.
set -euo pipefail

add_target() {
  local key="$1" target_arg="$2" val
  val="${!key:-}"
  if [[ -n "$val" && "$val" != *"--target="* ]]; then
    export "${key}=${target_arg} ${val}"
    echo "cargo-bindgen-target: added ${target_arg}" >&2
  else
    echo "cargo-bindgen-target: left ${key} unchanged" >&2
  fi
}

# One entry per android rust triple the sc-release matrix builds. The API
# level matches the --platform each ndk_*.sh passes to cargo-ndk.
add_target BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android --target=aarch64-linux-android24
add_target BINDGEN_EXTRA_CLANG_ARGS_armv7_linux_androideabi --target=armv7-linux-androideabi21
add_target BINDGEN_EXTRA_CLANG_ARGS_x86_64_linux_android --target=x86_64-linux-android21

real=$(command -v cargo)
if [[ "$(readlink -f "$real")" == "$(readlink -f "$0")" ]]; then
  echo "cargo-bindgen-target: refusing to exec itself" >&2
  exit 1
fi
export CARGO="$real"
echo "cargo-bindgen-target: cargo $*" >&2
exec "$real" "$@"
