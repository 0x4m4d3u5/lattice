#!/usr/bin/env bash
# Run every gate even if an earlier one fails; preserve each command's exit code.
set -u
cd "$(dirname "$0")/.."
status=0
bash scripts/verify-ci-toolchain.sh || exit $?
export PATH="$MOON_HOME/bin:$PATH"
for gate in check test build; do
  echo "Running moon $gate --target js --deny-warn"
  moon "$gate" --target js --deny-warn || status=1
done
echo "Running vendored clap tests --target js --deny-warn"
moon -C vendor/clap test --target js --deny-warn -p TheWaWaR/clap || status=1
echo "Running CLI cross-note heading fixture"
node scripts/check-wikilink-headings.mjs || status=1
echo "Running generated-output navigation fixture"
node scripts/check-navigation-overwrites.mjs || status=1
exit "$status"
