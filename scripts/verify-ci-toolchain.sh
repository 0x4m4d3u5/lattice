#!/usr/bin/env bash
# Validate the supported JS profile, including tools restored from a cache.
set -euo pipefail
: "${MOON_HOME:?Set MOON_HOME to the installed toolchain directory}"
MOON_HOME=$(realpath -m "$MOON_HOME")
export MOON_HOME
[[ "$(uname -ms)" == 'Linux x86_64' ]] || { echo 'Expected Linux x86_64' >&2; exit 1; }
[[ "$(node --version)" == 'v26.12.1' ]] || { echo 'Expected Node 26.12.1' >&2; exit 1; }
cd "$MOON_HOME"
sha256sum --check --strict <<'HASHES'
82d578b85d7ae9ee0e312c94bad613fa6125c6f03d7e1de0a1a539d78bfdb68b  bin/moon
f02eeee7b77a7f581dfbb0c3788f8de4396b57c950219f40d08cc038479a12fb  bin/moonrun
e09423bf0a3e854f12feb4fd89e26a30a85a7e67b85bbd23542fa4d0e3e40c4f  bin/moonc
48052dcb835f9ce82d3e9f3561c04cbd47968bce06092ded64b111a827bcf35c  bin/moonfmt
8b162c965308664c391a9700a7299f96aa07db44069f2ac0116b4dc09855df7c  bin/mooninfo
0bb2dcc3ff2d47ff7fb47c7db52bb5f177f86e0735fedb912ea7e60ceed30791  bin/moonc.assets/code-0e02823df004193f552b.wasm
66ee24e71521baae35f4f9afb6f6022795db0d0276a68840ae1927ebe091a1f0  bin/moonfmt.assets/code-8b2a10061e50c725b1a3.wasm
b86d79575da65f6d00a821710f5df86dcb5bcf3dda05d4123c6d247684a5e2e1  bin/mooninfo.assets/code-5dea568b86861b90270b.wasm
91afee2c0641615349367de11818c5d6bef0b39744acc611def89b07a1d2804e  lib/core/moon.mod
HASHES
[[ -f lib/core/_build/js/release/bundle/builtin/builtin.core ]] || { echo 'Missing bundled JS core' >&2; exit 1; }
version=$(bin/moon version --all)
[[ "$version" == *'moonc v0.10.18+6c83a7f62'* && "$version" == *'(e1e1f15'* ]] || { echo 'Unexpected toolchain version' >&2; exit 1; }
printf '%s\n' "$version"
