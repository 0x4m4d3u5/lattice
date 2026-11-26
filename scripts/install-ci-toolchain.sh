#!/usr/bin/env bash
# Install the pinned official native-hosted compiler and matching core.
# JS tests use Node; the CLI also requires its bundled Moonrun to resolve tools.
set -euo pipefail
: "${MOON_HOME:?Set MOON_HOME to a task/job toolchain directory}"
MOON_HOME=$(realpath -m "$MOON_HOME")
export MOON_HOME
script_dir=$(cd "$(dirname "$0")" && pwd)
if [[ -e "$MOON_HOME" ]]; then
  bash "$script_dir/verify-ci-toolchain.sh"
  exit
fi
[[ "$(uname -ms)" == 'Linux x86_64' ]] || { echo 'Expected Linux x86_64' >&2; exit 1; }
[[ "$(node --version)" == 'v26.12.1' ]] || { echo 'Expected Node 26.12.1' >&2; exit 1; }
work_dir=$(mktemp -d)
staging_dir=''
trap 'rm -rf "$work_dir"; [[ -z "$staging_dir" ]] || rm -rf "$staging_dir"' EXIT
version='1.0.0-rc1%2B3c0520448'
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/cores/core-$version.tar.gz" \
  -o "$work_dir/core.tar.gz"
# The native archive includes the compiler, CLI, Moonrun and C runtime.
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/binaries/$version/moonbit-linux-x86_64.tar.gz" \
  -o "$work_dir/cli.tar.gz"
printf '%s  %s\n' \
  'a3f7d82f1195e28ad9aad7b9b8b4cbca490cbf8146b306a376ea3beba4173751' "$work_dir/core.tar.gz" \
  '113527a9037fe12e463e6ac1e7698116bf703730243096328e4ac7e2774307c0' "$work_dir/cli.tar.gz" \
  | sha256sum --check --strict
mkdir -p "$(dirname "$MOON_HOME")"
staging_dir=$(mktemp -d "$MOON_HOME.install.XXXXXX")
tar xf "$work_dir/cli.tar.gz" -C "$staging_dir"
chmod +x "$staging_dir"/bin/* "$staging_dir/bin/internal/tcc"
tar xf "$work_dir/core.tar.gz" -C "$staging_dir/lib"
grep -Fxq 'version = "1.0.0-rc1+3c0520448"' "$staging_dir/lib/core/moon.mod" \
  || { echo 'Unexpected core version' >&2; exit 1; }
MOON_HOME="$staging_dir" PATH="$staging_dir/bin:$PATH" "$staging_dir/bin/moon" -C "$staging_dir/lib/core" bundle --target js
MOON_HOME="$staging_dir" bash "$script_dir/verify-ci-toolchain.sh"
# Promote only a fully installed and verified toolchain; leave existing directories intact.
[[ ! -e "$MOON_HOME" ]] || { echo "Refusing to overwrite $MOON_HOME" >&2; exit 1; }
mv --no-clobber --no-target-directory "$staging_dir" "$MOON_HOME"
[[ ! -d "$staging_dir" ]] || { echo "Refusing to overwrite $MOON_HOME" >&2; exit 1; }
staging_dir=''
