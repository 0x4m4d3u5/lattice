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
version='0.10.18%2B6c83a7f62'
curl --fail --location --silent --show-error \
  "https://github.com/moonbitlang/moonbit-compiler/releases/download/v$version/moonbit-wasm.tar.gz" \
  -o "$work_dir/compiler.tar.gz"
# The native archive includes the compiler, CLI, Moonrun and C runtime.
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/binaries/$version/moonbit-linux-x86_64.tar.gz" \
  -o "$work_dir/cli.tar.gz"
printf '%s  %s\n' \
  'c666b3b45db79e2a1a477cc9e99812223700d645d33d9834c95216208926fed1' "$work_dir/compiler.tar.gz" \
  '0e4cde1ace98e8ef00552a937738b59c6901c4b8a004ebad71ea0e63688f63f1' "$work_dir/cli.tar.gz" \
  | sha256sum --check --strict
mkdir "$work_dir/compiler"
tar xf "$work_dir/compiler.tar.gz" -C "$work_dir/compiler"
[[ "$(cat "$work_dir/compiler/moon_version")" == '5439c5789965cd1d8f148317af21d85316663ff9' ]] \
  || { echo 'Unexpected compiler SDK revision' >&2; exit 1; }
mkdir -p "$(dirname "$MOON_HOME")"
staging_dir=$(mktemp -d "$MOON_HOME.install.XXXXXX")
tar xf "$work_dir/cli.tar.gz" -C "$staging_dir"
chmod +x "$staging_dir"/bin/* "$staging_dir/bin/internal/tcc"
tar xf "$work_dir/compiler/core.tar.gz" -C "$staging_dir/lib"
MOON_HOME="$staging_dir" PATH="$staging_dir/bin:$PATH" "$staging_dir/bin/moon" -C "$staging_dir/lib/core" bundle --target js
MOON_HOME="$staging_dir" bash "$script_dir/verify-ci-toolchain.sh"
# Promote only a fully installed and verified toolchain; leave existing directories intact.
[[ ! -e "$MOON_HOME" ]] || { echo "Refusing to overwrite $MOON_HOME" >&2; exit 1; }
mv --no-clobber --no-target-directory "$staging_dir" "$MOON_HOME"
[[ ! -d "$staging_dir" ]] || { echo "Refusing to overwrite $MOON_HOME" >&2; exit 1; }
staging_dir=''
