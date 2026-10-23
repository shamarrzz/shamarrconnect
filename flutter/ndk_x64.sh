#!/usr/bin/env bash
# Same NDK r30 bindgen workaround as ndk_arm64.sh — see
# cargo-bindgen-target.sh for why the CARGO wrapper is needed.
here=$(cd "$(dirname "$0")" && pwd)
ndk=$(command -v cargo-ndk)
if [[ -z "$ndk" || ! -x "$ndk" ]]; then
  echo "cargo-ndk is not on PATH" >&2
  exit 1
fi
export CARGO="${here}/cargo-bindgen-target.sh"
"$ndk" ndk --platform 21 --target x86_64-linux-android build --locked --release --features flutter
