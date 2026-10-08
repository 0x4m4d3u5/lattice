#!/usr/bin/env bash
# Run every gate even if an earlier one fails; preserve each command's exit code.
set -u
cd "$(dirname "$0")/.."
status=0
toolchain_version=$(moon version --all) || exit $?
printf '%s\n' "$toolchain_version"
if [[ "$toolchain_version" != *"moonc v0.10.14+7d59c7ec9"* || "$toolchain_version" != *"(760759c"* ]]; then
  echo "Expected moonc 0.10.14+7d59c7ec9 and Moon commit 760759ca; see docs/reliability-baseline.md" >&2
  exit 1
fi
for gate in check test build; do
  echo "Running moon $gate --target js"
  moon "$gate" --target js || status=1
done
echo "Running vendored clap tests --target js"
moon -C vendor/clap test --target js || status=1
exit "$status"
