#!/usr/bin/env bash
# Exercise generated application WASM without the interpolation-broken test driver.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-ci-toolchain.sh
export PATH="$MOON_HOME/bin:$PATH"
for target in wasm wasm-gc; do
  moon -C "$MOON_HOME/lib/core" bundle --target "$target" --deny-warn
  moon build tests/wasm_core --target "$target" --deny-warn
  node scripts/run-wasm-core.mjs \
    "_build/$target/debug/build/kurisu/lattice/tests/wasm_core/wasm_core.wasm"
done
