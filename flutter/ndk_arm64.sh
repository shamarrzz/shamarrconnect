#!/usr/bin/env bash
# NDK r30 rejects a clang target with no API level. cargo-ndk 4.1.2 sets
# the target-specific bindgen args without --target, and bindgen 0.59
# ignores BINDGEN_EXTRA_CLANG_ARGS when that variable is set. `cargo`
# replaces CARGO before it runs a subcommand, so call cargo-ndk directly
# and let the wrapper add API 24, the same floor as minSdk.
here=$(cd "$(dirname "$0")" && pwd)
export CARGO="${here}/cargo-bindgen-target.sh"
cargo-ndk --platform 24 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
