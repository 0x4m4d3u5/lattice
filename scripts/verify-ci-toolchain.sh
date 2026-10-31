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
82d578b85d7ae9ee0e312c94bad613fa6125c6f03d7e1de0a1a539d78bfdb68b  bin/moon
f02eeee7b77a7f581dfbb0c3788f8de4396b57c950219f40d08cc038479a12fb  bin/moonrun
8fc8030b74df0f42df7a1413f4f15ae9cc6cc31baff9e293f1b41833a759d607  bin/moonc
b180d23755d0f53728dc20304b7dc83cc607b2e059a0c4e44d5aa286911ae1f6  bin/moonfmt
71fa8da21ffa11cdf7b1281b054e57eb8d70ff0a5daacb5c78eb461823867fa4  bin/mooninfo
c3771d17f7fc328995f80b5c965097886e16495b1d42fe08daacea64f2d77e9c  bin/internal/tcc
bde52fce6b2c0bcdb92b4226c27a0f23b5daf729fbe83577a976536dc0cd80e1  include/moonbit.h
91afee2c0641615349367de11818c5d6bef0b39744acc611def89b07a1d2804e  lib/core/moon.mod
HASHES
[[ -f lib/core/_build/js/release/bundle/builtin/builtin.core ]] || { echo 'Missing bundled JS core' >&2; exit 1; }
version=$(bin/moon version --all)
[[ "$version" == *'moonc v0.10.18+6c83a7f62'* && "$version" == *'(e1e1f15'* ]] || { echo 'Unexpected toolchain version' >&2; exit 1; }
printf '%s\n' "$version"
