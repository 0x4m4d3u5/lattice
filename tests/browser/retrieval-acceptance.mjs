import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { createContentSearcher } from '../../examples/wasm_note/host.mjs';
import { collectEvidence, validatePublishedTarget } from '../../examples/agent_evidence/evidence.mjs';
import { search_content } from '../../_build/js/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.js';

// Questions and passage expectations are authored in the fixture, not derived from search output.
const corpus = JSON.parse(readFileSync(new URL('./fixtures/retrieval/corpus.json', import.meta.url)));
const root = mkdtempSync(join(tmpdir(), 'lattice-retrieval-acceptance-'));
for (const dir of ['content/notes', 'templates', 'data']) mkdirSync(join(root, dir), { recursive: true });
for (const [name, text] of Object.entries(corpus.notes)) writeFileSync(join(root, 'content/notes', name + '.md'), text);
writeFileSync(join(root, 'content/lattice.conf'), 'title = Retrieval acceptance\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\ncontent_index_file = content-index.json\nwikilink_aliases = true\n');
writeFileSync(join(root, 'collections.cfg'), '[notes]\ndir = content/notes\nschema = title:String\n');
writeFileSync(join(root, 'templates/page.html'), '<!doctype html><meta charset="utf-8"><article>{{body_no_h1}}</article>');
const cli = process.env.LATTICE_NATIVE_CLI ?? fileURLToPath(new URL('../../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const build = (flags = []) => {
  const result = spawnSync(process.env.LATTICE_NATIVE_CLI ? cli : process.execPath,
    [...(process.env.LATTICE_NATIVE_CLI ? [] : [cli]), 'build', '--strict-wikilinks', ...flags], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return readFileSync(join(root, 'dist/content-index.json'), 'utf8');
};
const indexJson = build();
const index = JSON.parse(indexJson);
assert.ok(!index.some(entry => entry.url === '/notes/draft/'));
const files = new Map(index.filter(entry => entry.sections?.length).map(entry => [entry.url, join(root, 'dist', entry.url, 'index.html')]));
const server = createServer((req, res) => {
  const file = files.get(new URL(req.url, 'http://localhost').pathname);
  if (!file) { res.writeHead(404); res.end(); return; }
  res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(readFileSync(file));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser;
try {
  browser = await chromium.launch({ chromiumSandbox: true, ...(process.env.LATTICE_BROWSER_CHANNEL ? { channel: process.env.LATTICE_BROWSER_CHANNEL } : {}) });
  const context = await browser.newContext({ javaScriptEnabled: false });
  const wasm = await createContentSearcher(readFileSync(new URL('../../_build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm', import.meta.url)));
  const js = async (...args) => JSON.parse(search_content(...args));
  let validations = 0;
  const collect = (test, search, source = indexJson) => collectEvidence({ indexJson: source, query: test.query, search, origin,
    validateTarget: (url, fragment) => { validations++; return validatePublishedTarget(context, url, fragment); } });
  const verify = (test, result) => {
    assert.equal(result.status, test.status, test.question);
    const targets = result.candidates.map(c => c.page + (c.fragment ? '#' + encodeURIComponent(c.fragment) : '')).sort();
    assert.deepEqual(targets, [...test.targets].sort(), test.question);
    if (test.status === 'ready') {
      assert.equal(result.citation.url, origin + test.targets[0]);
      assert.ok(result.candidates[0].passage.includes(test.passage), test.question);
    } else assert.ok(!result.citation, 'abstention must not select a citation');
  };
  for (const test of corpus.cases) {
    const before = validations;
    const a = await collect(test, js); const b = await collect(test, wasm);
    verify(test, a); verify(test, b); assert.deepEqual(a, b, 'JS/WASM retrieval must agree');
    if (test.status !== 'ready') assert.equal(validations, before, 'abstention must not validate a chosen target');
  }
  // Controls show the oracle rejects plausible wrong behavior, not merely empty output.
  const relevant = corpus.cases[0];
  await assert.rejects(async () => verify(relevant, await collect(relevant, async () => ({ results: [], error: null }))));
  const ambiguous = corpus.cases.find(test => test.status === 'ambiguous');
  const topOnly = async (...args) => { const r = await wasm(...args); return { ...r, results: r.results.slice(0, 1) }; };
  await assert.rejects(async () => verify(ambiguous, await collect(ambiguous, topOnly)));
  const absent = corpus.cases.find(test => test.query === 'retention duration');
  const draftIndex = build(['--drafts']);
  files.set('/notes/draft/', join(root, 'dist/notes/draft/index.html'));
  const leaked = await collect(absent, wasm, draftIndex);
  assert.equal(leaked.status, 'ready', 'draft control must expose a real published passage');
  assert.equal(leaked.candidates[0]?.page, '/notes/draft/', 'draft control must retrieve actual excluded text');
  assert.throws(() => verify(absent, leaked), 'oracle must detect accidental draft inclusion');
  const withoutAnswer = JSON.stringify(index.filter(entry => entry.url !== '/notes/operations/'));
  assert.equal((await collect(relevant, wasm, withoutAnswer)).status, 'no_results', 'competing topics cannot replace the removed evidence');
  console.log('Retrieval acceptance: independently authored passages, lexical limits, competing topics, aliases, draft exclusions, validated citations and negative controls passed');
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
