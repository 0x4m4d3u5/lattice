#!/usr/bin/env bash
# Official pinned Linux distribution; no Rust or toolchain source build.
set -euo pipefail
: "${MOON_HOME:?Set MOON_HOME to a fresh task/job directory}"
[[ ! -e "$MOON_HOME" ]] || { echo "Refusing to overwrite $MOON_HOME" >&2; exit 1; }
[[ "$(uname -ms)" == 'Linux x86_64' ]] || { echo "Expected Linux x86_64" >&2; exit 1; }
[[ "$(node --version)" == 'v26.10.0' ]] || { echo "Expected Node 26.10.0" >&2; exit 1; }
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
version='0.10.14%2B7d59c7ec9'
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/binaries/$version/moonbit-linux-x86_64.tar.gz" \
  -o "$work_dir/toolchain.tar.gz"
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/cores/core-$version.tar.gz" \
  -o "$work_dir/core.tar.gz"
printf '%s  %s\n' \
  '9226694de9ff978db1ecf820b7710c4224e84ec7a76b19a222d96f0cd4e31b6a' "$work_dir/toolchain.tar.gz" \
  '6f18b8fdea18f85e628a75e4a1bd3977c5a5c9c6a836fd8824192b0e6bd91b14' "$work_dir/core.tar.gz" \
  | sha256sum --check --strict
mkdir -p "$MOON_HOME"
tar xf "$work_dir/toolchain.tar.gz" -C "$MOON_HOME"
tar xf "$work_dir/core.tar.gz" -C "$MOON_HOME/lib"
chmod +x "$MOON_HOME"/bin/* "$MOON_HOME/bin/internal/tcc"
export PATH="$MOON_HOME/bin:$PATH"
toolchain_version=$(moon version --all)
[[ "$toolchain_version" == *'moonc v0.10.14+7d59c7ec9'* && "$toolchain_version" == *'(914d7da'* ]] \
  || { echo "Unexpected prebuilt toolchain version" >&2; exit 1; }
moon -C "$MOON_HOME/lib/core" bundle --target js
moon version --all
