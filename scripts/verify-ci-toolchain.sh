#!/usr/bin/env bash
# Validate the supported JS profile, including tools restored from a cache.
set -euo pipefail
: "${MOON_HOME:?Set MOON_HOME to the installed toolchain directory}"
MOON_HOME=$(realpath -m "$MOON_HOME")
export MOON_HOME
[[ "$(uname -ms)" == 'Linux x86_64' ]] || { echo 'Expected Linux x86_64' >&2; exit 1; }
[[ "$(node --version)" == 'v26.10.0' ]] || { echo 'Expected Node 26.10.0' >&2; exit 1; }
cd "$MOON_HOME"
sha256sum --check --strict <<'HASHES'
6da4919f45f4abf7c6d7f3cf8d9a457de77dca430d6fb811d21b27ae1ac8e11d  bin/moon
1b22f489621059b8c22ee4acdaddc5f5d1781f62529d3000a24c03d45032d0e2  bin/moonrun
7b3c7e35077a44be528044f1823fdaadf0e0917cc0fbab082b279d00dae98038  bin/moonc
fcba7920f54f899b913ab43e1ffc813162430ddbc218f86af475e9923b61dc96  bin/moonfmt
a02b12e005b7fd3fa3a9172e5a9160ff5e808e7a98f8b0577bab0084e7dc4d96  bin/mooninfo
fa088fbc9d6801eabe8643fd83ebe205b28022497679372cdefa343883ea54b1  bin/moonc.assets/code-76b97363c4e10c5b1392.wasm
05104875ac81d1a9a362bad303353d3f8930764e443d976128210cfb29796e0b  bin/moonfmt.assets/code-5316c345641f48b71257.wasm
fbd9c8d140ce698d60f1584730a684c4f590828ae1f5638e859d71437c5dec38  bin/mooninfo.assets/code-8945dda8c778bf3d2f7f.wasm
HASHES
[[ -f lib/core/_build/js/release/bundle/builtin/builtin.core ]] || { echo 'Missing bundled JS core' >&2; exit 1; }
version=$(bin/moon version --all)
[[ "$version" == *'moonc v0.10.14+7d59c7ec9'* && "$version" == *'(914d7da'* ]] || { echo 'Unexpected toolchain version' >&2; exit 1; }
printf '%s\n' "$version"
