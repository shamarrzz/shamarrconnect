#!/usr/bin/env bash
cargo ndk --platform 24 --target aarch64-linux-android build --locked --release --features flutter,hwcodec
