#!/usr/bin/env bash
# Verify a supplied-text ABI separately from fixed, import-free core fixtures.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-ci-toolchain.sh
export PATH="$MOON_HOME/bin:$PATH"
moon -C "$MOON_HOME/lib/core" bundle --target wasm-gc --deny-warn
for target in js wasm-gc; do
  moon build examples/wasm_note --target "$target" --deny-warn
done
node scripts/run-wasm-note.mjs \
  _build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm \
  _build/js/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.js
