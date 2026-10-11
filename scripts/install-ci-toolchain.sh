#!/usr/bin/env bash
# Install the durable WASM compiler and the verified open-source Moon CLI.
# JS tests use Node: no Rust build, moonrun, or expiring native compiler is needed.
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
[[ "$(node --version)" == 'v26.10.0' ]] || { echo 'Expected Node 26.10.0' >&2; exit 1; }
work_dir=$(mktemp -d)
staging_dir=''
trap 'rm -rf "$work_dir"; [[ -z "$staging_dir" ]] || rm -rf "$staging_dir"' EXIT
version='0.10.14%2B7d59c7ec9'
curl --fail --location --silent --show-error \
  "https://github.com/moonbitlang/moonbit-compiler/releases/download/v$version/moonbit-wasm.tar.gz" \
  -o "$work_dir/compiler.tar.gz"
# This archive supplies only the Rust Moon CLI; its native compiler is never extracted.
curl --fail --location --silent --show-error \
  "https://cli.moonbitlang.com/binaries/$version/moonbit-linux-x86_64.tar.gz" \
  -o "$work_dir/cli.tar.gz"
printf '%s  %s\n' \
  '3c5d21564b0e8bbfcfda95d374eda90427f6a5e238ce4639b711b69f43391f62' "$work_dir/compiler.tar.gz" \
  '9226694de9ff978db1ecf820b7710c4224e84ec7a76b19a222d96f0cd4e31b6a' "$work_dir/cli.tar.gz" \
  | sha256sum --check --strict
mkdir "$work_dir/compiler"
tar xf "$work_dir/compiler.tar.gz" -C "$work_dir/compiler"
[[ "$(cat "$work_dir/compiler/moon_version")" == '760759ca67539dd6b6ea59b1eba57731b3ef674a' ]] \
  || { echo 'Unexpected compiler SDK revision' >&2; exit 1; }
mkdir -p "$(dirname "$MOON_HOME")"
staging_dir=$(mktemp -d "$MOON_HOME.install.XXXXXX")
mkdir "$staging_dir/bin" "$staging_dir/lib"
tar xf "$work_dir/cli.tar.gz" --strip-components=2 -C "$staging_dir/bin" ./bin/moon
chmod +x "$staging_dir/bin/moon"
for name in moonc moonfmt mooninfo; do
  { printf '%s\n' '#!/usr/bin/env -S node --stack-size=4096'; cat "$work_dir/compiler/$name.js"; } > "$staging_dir/bin/$name"
  chmod +x "$staging_dir/bin/$name"
  cp -R "$work_dir/compiler/$name.assets" "$staging_dir/bin/"
done
cp -R "$work_dir/compiler/lib/." "$staging_dir/lib/"
cp -R "$work_dir/compiler/include" "$staging_dir/"
tar xf "$work_dir/compiler/core.tar.gz" -C "$staging_dir/lib"
MOON_HOME="$staging_dir" PATH="$staging_dir/bin:$PATH" "$staging_dir/bin/moon" -C "$staging_dir/lib/core" bundle --target js
MOON_HOME="$staging_dir" bash "$script_dir/verify-ci-toolchain.sh"
# Promote only a fully installed and verified toolchain; leave existing directories intact.
[[ ! -e "$MOON_HOME" ]] || { echo "Refusing to overwrite $MOON_HOME" >&2; exit 1; }
mv --no-clobber --no-target-directory "$staging_dir" "$MOON_HOME"
[[ ! -d "$staging_dir" ]] || { echo "Refusing to overwrite $MOON_HOME" >&2; exit 1; }
staging_dir=''
