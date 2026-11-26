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
d67a95d0f7d7264bd3275eae58b4f6f5b9b0272f36abb26f849245e046eca438  bin/moon
9da286a2570eefbf825e945ed38290039902f978884be6457a16f93aa0e88f6d  bin/moonrun
7906a2bde979fad1ff9894f350ffb1be81466318d2e4304a2ed5e59402e34126  bin/moonc
30acc9333d028dd1cac32dfa8836e146d77733bbf12c0eb7b7b709ceea96d9de  bin/moonfmt
3afed31029791d8fb70fb5644db67d5af11bb8b795544264827a94d98978f5c1  bin/mooninfo
d20639cbabd07bdc4796b4b0eed5cd070f5f2e152b515f3f6fc68387f142c3b2  bin/internal/tcc
36196f493a6457c381ea4d391f289216ffb8aa44032271c62e19e238b7e0ccea  include/moonbit.h
2c00dd051194e0ac1113e3cf12f93e110dd28ae67cbc53d27aa035ceddcb1304  lib/core/moon.mod
HASHES
[[ -f lib/core/_build/js/release/bundle/builtin/builtin.core ]] || { echo 'Missing bundled JS core' >&2; exit 1; }
version=$(bin/moon version --all)
grep -Eq '^moon 0\.1\.20261126 \(ccd306a ' <<< "$version" &&
  grep -Eq '^moonc v1\.0\.0-rc1\+3c0520448 ' <<< "$version" &&
  grep -Eq '^moonrun 0\.1\.20261126 \(ccd306a ' <<< "$version" \
  || { echo 'Unexpected toolchain version' >&2; exit 1; }
printf '%s\n' "$version"
