#!/usr/bin/env bash
# NDK r30 rejects a clang target with no API level. cargo-ndk 4.1.2 sets
# the target-specific bindgen args without --target, and bindgen 0.59
# ignores BINDGEN_EXTRA_CLANG_ARGS when that variable is set. `cargo`
# replaces CARGO before it runs a subcommand, so call cargo-ndk directly
# and let the wrapper add API 24, the same floor as minSdk.
# cargo-ndk 4.1.2 canonicalizes argv[0] and panics when that is only the
# command name, so the call has to be the absolute path.
here=$(cd "$(dirname "$0")" && pwd)
ndk=$(command -v cargo-ndk)
if [[ -z "$ndk" || ! -x "$ndk" ]]; then
  echo "cargo-ndk is not on PATH" >&2
  exit 1
fi
export CARGO="${here}/cargo-bindgen-target.sh"
"$ndk" --platform 24 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
