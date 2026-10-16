#!/usr/bin/env bash
# NDK r30 rejects a clang target with no API level. The codec build calls
# clang with the bare Android triple, so pin API 24, the same floor as minSdk.
export BINDGEN_EXTRA_CLANG_ARGS="${BINDGEN_EXTRA_CLANG_ARGS:-} --target=aarch64-linux-android24"
cargo ndk --platform 24 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
