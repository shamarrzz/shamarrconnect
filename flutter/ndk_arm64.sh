#!/usr/bin/env bash
# NDK r30 rejects a clang target with no API level. The generic
# BINDGEN_EXTRA_CLANG_ARGS export does not reach bindgen 0.59, because
# cargo-ndk sets the target-specific variable without --target. The wrapper
# adds API 24, the same floor as minSdk, after cargo-ndk has set that variable.
here=$(cd "$(dirname "$0")" && pwd)
export CARGO="${here}/cargo-bindgen-target.sh"
cargo ndk --platform 24 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
