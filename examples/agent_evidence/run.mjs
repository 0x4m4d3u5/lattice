import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { collectEvidence, validatePublishedTarget } from './evidence.mjs';
import { createContentSearcher } from '../wasm_note/host.mjs';
const args = process.argv.slice(2);
const strictCitations = args[0] === '--strict-citations';
if (strictCitations) args.shift();
if (args.length !== 3 || args[0].startsWith('--')) throw new Error('Usage: node examples/agent_evidence/run.mjs [--strict-citations] CONTENT_INDEX_JSON PUBLICATION_ORIGIN "lexical query"');
const [indexPath, origin, query] = args;
// Reuse the repository's pinned browser harness; no new production dependency.
const { chromium } = createRequire(new URL('../../tests/browser/package.json', import.meta.url))('playwright');
const indexJson = await readFile(indexPath, 'utf8');
const bytes = await readFile(new URL('../../_build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm', import.meta.url));
const search = await createContentSearcher(bytes);
const browser = await chromium.launch({ chromiumSandbox: true, ...(process.env.LATTICE_BROWSER_CHANNEL ? { channel: process.env.LATTICE_BROWSER_CHANNEL } : {}) });
try {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const result = await collectEvidence({ indexJson, query, origin, search, strictCitations,
    validateTarget: (url, fragment, publication, passage) => validatePublishedTarget(context, url, fragment, publication, passage) });
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== 'ready' || [result.pairing?.status, result.retention?.status].some(status => ['mismatched', 'invalid'].includes(status))) process.exitCode = 2;
} finally { await browser.close(); }
