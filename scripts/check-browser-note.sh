#!/usr/bin/env bash
# Browser dependencies are installed explicitly; never silently fetch at test time.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-ci-toolchain.sh
export PATH="$MOON_HOME/bin:$PATH"
moon -C "$MOON_HOME/lib/core" bundle --target wasm-gc --deny-warn
moon build examples/wasm_note --target wasm-gc --deny-warn
moon build cmd/main --target js --deny-warn
npm test --prefix tests/browser
