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
echo "Running copied getting-started workflow"
node scripts/check-getting-started.mjs || status=1
echo "Running copied README author workflow"
node scripts/check-readme.mjs || status=1
echo "Running machine-readable CLI check fixture"
node scripts/check-cli-json.mjs || status=1
echo "Running JavaScript watch author workflow"
node scripts/check-js-watch.mjs || status=1
echo "Running JavaScript live preview workflow"
node scripts/check-js-serve.mjs || status=1
echo "Running root and standalone watch workflow"
node scripts/check-watch-pages.mjs || status=1
echo "Running schema-driven new-content fixture"
node scripts/check-new-content.mjs || status=1
echo "Running strict build publication gate"
node scripts/check-strict-build.mjs || status=1
echo "Running Obsidian callout publishing workflow"
node scripts/check-obsidian-callouts.mjs || status=1
echo "Running CLI cross-note heading fixture"
node scripts/check-wikilink-headings.mjs || status=1
echo "Running final HTML wikilink fragment fixture"
node scripts/check-wikilink-fragments.mjs || status=1
echo "Running generated-output navigation fixture"
node scripts/check-navigation-overwrites.mjs || status=1
echo "Running root and standalone tag-index fixture"
node scripts/check-page-tags.mjs || status=1
echo "Running final tag-plan fixture"
node scripts/check-tag-final-plan.mjs || status=1
echo "Running graph edge-identity fixture"
node scripts/check-graph-edge-identity.mjs || status=1
echo "Running published passage fragment fixture"
node scripts/check-passage-fragments.mjs || status=1
echo "Running section retrieval publishing fixture"
node scripts/check-section-search.mjs || status=1
echo "Running read-only publication inventory fixture"
node scripts/check-publication-inventory.mjs || status=1
echo "Running conservative link suggestion fixture"
node scripts/check-link-suggestions.mjs || status=1
echo "Running local image attachment workflow"
node scripts/check-image-embeds.mjs || status=1
echo "Running alternate note name workflow"
node scripts/check-note-aliases.mjs || status=1
echo "Running saved inventory comparison fixture"
node scripts/check-inventory-diff.mjs || status=1
echo "Running synthetic vault acceptance"
moon -C "$MOON_HOME/lib/core" bundle --target wasm-gc --deny-warn &&
  moon build examples/wasm_note --target wasm-gc --deny-warn &&
  node scripts/check-vault-acceptance.mjs || status=1

echo "Running authored reader metadata workflow"
node scripts/check-reader-metadata.mjs || status=1
node scripts/check-contextual-backlinks.mjs || status=1
exit "$status"
