#!/usr/bin/env bash
# Validate the native-hosted compiler profile, including cached installations.
set -euo pipefail
: "${MOON_HOME:?Set MOON_HOME to the installed toolchain directory}"
MOON_HOME=$(realpath -m "$MOON_HOME")
export MOON_HOME
[[ "$(uname -ms)" == 'Linux x86_64' ]] || { echo 'Expected Linux x86_64' >&2; exit 1; }
[[ "$(node --version)" == 'v26.12.1' ]] || { echo 'Expected Node 26.12.1' >&2; exit 1; }
cd "$MOON_HOME"
sha256sum --check --strict <<'HASHES'
3fdfe18b453e619c707eb8ec50f1277a834bdb840a6e85094102b8978b06ef2e  bin/moon
38718520d7b86e6b12aebd69e075d739f17964c58586c256bb7637bfe86d1fb7  bin/moonrun
ec9d278bc212bf47e9ae38457e53635c2d9590aeb3ff1db18356afc8a2872f4f  bin/moonc
0519f4fabcc5804f2f7e4a5d96d9e6a5617017441df66bdda679b93ba5142559  bin/moonfmt
ec1343ffeb02b0fef2355482fa30aa177f5ae33f6f0fc8a8d4a944401d4d9ed1  bin/mooninfo
b7d046ca5ef9037a8164c7d0bc9acd9dc31928782a8693a94d9741999996e28a  bin/internal/tcc
bde52fce6b2c0bcdb92b4226c27a0f23b5daf729fbe83577a976536dc0cd80e1  include/moonbit.h
9ca82e0ea960ff9665b14b446aa7c21c30e2255b9cd7d5661a8e3033e367d185  lib/core/moon.mod
HASHES
[[ -f lib/core/_build/js/release/bundle/builtin/builtin.core ]] || { echo 'Missing bundled JS core' >&2; exit 1; }
version=$(bin/moon version --all)
[[ "$version" == *'moonc v0.10.20+65efd5b93'* && "$version" == *'(940aa18'* ]] || { echo 'Unexpected toolchain version' >&2; exit 1; }
printf '%s\n' "$version"
