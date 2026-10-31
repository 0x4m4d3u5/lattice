import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { collectEvidence, validatePublishedTarget } from './evidence.mjs';
import { createContentSearcher } from '../wasm_note/host.mjs';
// Reuse the repository's pinned browser harness; no new production dependency.
const { chromium } = createRequire(new URL('../../tests/browser/package.json', import.meta.url))('playwright');
if (process.argv.length !== 5) throw new Error('Usage: node examples/agent_evidence/run.mjs CONTENT_INDEX_JSON PUBLICATION_ORIGIN "lexical query"');
const indexJson = await readFile(process.argv[2], 'utf8');
const bytes = await readFile(new URL('../../_build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm', import.meta.url));
const search = await createContentSearcher(bytes);
const browser = await chromium.launch({ chromiumSandbox: true, ...(process.env.LATTICE_BROWSER_CHANNEL ? { channel: process.env.LATTICE_BROWSER_CHANNEL } : {}) });
try {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const result = await collectEvidence({ indexJson, query: process.argv[4], origin: process.argv[3], search,
    validateTarget: (url, fragment) => validatePublishedTarget(context, url, fragment) });
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== 'ready') process.exitCode = 2;
} finally { await browser.close(); }
