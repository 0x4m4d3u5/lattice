#!/usr/bin/env bash
# Test generated targets using the pinned native-hosted compiler.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-ci-toolchain.sh
export PATH="$MOON_HOME/bin:$PATH"
for target in wasm wasm-gc native; do
  moon -C "$MOON_HOME/lib/core" bundle --target "$target" --deny-warn
  flags=()
  # Native currently reports the existing JS/WASM-only env import in watch.
  # Preserve that visible warning; JS and both WASM targets deny warnings.
  [[ "$target" == native ]] || flags+=(--deny-warn)
  for gate in check test build; do
    moon "$gate" --target "$target" "${flags[@]}"
  done
  moon -C vendor/clap test --target "$target" "${flags[@]}" -p TheWaWaR/clap
done
node scripts/check-native-cli.mjs

LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-section-search.mjs
LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-image-embeds.mjs

LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-vault-acceptance.mjs

LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-reader-metadata.mjs
LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-contextual-backlinks.mjs

LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-local-links.mjs

LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-related-notes.mjs

LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-inventory-fragments.mjs

LATTICE_NATIVE_CLI="$PWD/_build/native/debug/build/kurisu/lattice/cmd/main/main.exe" node scripts/check-publication-pairing.mjs
