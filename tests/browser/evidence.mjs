import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync, spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { createContentSearcher } from '../../examples/wasm_note/host.mjs';
import { collectEvidence, validatePublishedTarget, comparePublication } from '../../examples/agent_evidence/evidence.mjs';
const repository = fileURLToPath(new URL('../../', import.meta.url));
const root = mkdtempSync(join(tmpdir(), 'lattice-evidence-'));
for (const dir of ['content/notes', 'templates', 'data']) mkdirSync(join(root, dir), { recursive: true });
writeFileSync(join(root, 'templates/page.html'), '<!doctype html><article>{{body_no_h1}}</article>');
writeFileSync(join(root, 'content/lattice.conf'), 'title = Evidence fixture\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\ncontent_index_file = content-index.json\n');
writeFileSync(join(root, 'collections.cfg'), '[notes]\ndir = content/notes\nschema = title:String\n');
const passage = 'Restore a backup into an isolated environment and compare its checksum. ' + 'Keep the test separate from production and record each observation before proceeding. '.repeat(5);
writeFileSync(join(root, 'content/notes/drill.md'), '---\ntitle: Recovery drill\n---\n## Verification\n\n' + passage);
writeFileSync(join(root, 'content/notes/alternative.md'), '---\ntitle: Alternative drill\n---\n## Restore\n\nRestore from a different replica after reviewing its age.');
writeFileSync(join(root, 'content/notes/draft.md'), '---\ntitle: Hidden\ndraft: true\n---\n## Secret\nplatinum draftmarker');
const cli = process.env.LATTICE_NATIVE_CLI ?? join(repository, '_build/js/debug/build/kurisu/lattice/cmd/main/main.js');
const built = spawnSync(process.env.LATTICE_NATIVE_CLI ? cli : process.execPath,
  [...(process.env.LATTICE_NATIVE_CLI ? [] : [cli]), 'build', '--strict-wikilinks'], { cwd: root, encoding: 'utf8' });
assert.equal(built.status, 0, built.stdout + built.stderr);
const indexPath = join(root, 'dist/content-index.json');
const indexJson = readFileSync(indexPath, 'utf8');
const index = JSON.parse(indexJson);
const entry = index.find(e => e.title === 'Recovery drill');
let html = readFileSync(join(root, 'dist', entry.url, 'index.html'), 'utf8');
const originalHtml = html;
const server = createServer((req, res) => {
  if (req.url === '/redirect/') { res.writeHead(302, { Location: entry.url }); res.end(); return; }
  if (req.url.split('#')[0] !== entry.url) { res.writeHead(404); res.end(); return; }
  res.setHeader('Content-Type', 'text/html; charset=utf-8'); res.end(html);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
const search = await createContentSearcher(readFileSync(join(repository, '_build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm')));
const browser = await chromium.launch({ chromiumSandbox: true, ...(process.env.LATTICE_BROWSER_CHANNEL ? { channel: process.env.LATTICE_BROWSER_CHANNEL } : {}) });
try {
  const context = await browser.newContext({ javaScriptEnabled: false });
  let validations = 0;
  const collect = (query, data = indexJson) => collectEvidence({ indexJson: data, query, search, origin,
    validateTarget: async (url, fragment, publication) => { validations++; return validatePublishedTarget(context, url, fragment, publication); } });
  const ready = await collect('isolated checksum');
  assert.equal(ready.status, 'ready');
  assert.equal(ready.pairing.status, 'matched');
  assert.equal(ready.candidates[0].passage, entry.sections[0].body);
  assert.ok(ready.candidates[0].passage.length > ready.candidates[0].snippet.length);
  assert.equal(ready.citation.url, origin + entry.url + '#verification');
  assert.equal((await collect('platinum')).status, 'no_results');
  const ambiguous = await collect('restore');
  assert.equal(ambiguous.status, 'ambiguous'); assert.equal(ambiguous.citation, null);
  assert.equal(ambiguous.candidates.length, 2); assert.equal(validations, 1, 'no-result/ambiguous evidence must not emit or validate a chosen citation');
  assert.equal((await collect('x', '{bad')).status, 'invalid_index');
  const duplicate = JSON.stringify([...index, entry]);
  assert.equal((await collect('isolated checksum', duplicate)).status, 'ambiguous_index');
  assert.equal((await collect('isolated checksum', duplicate)).pairing.status, 'invalid');
  const altered = change => JSON.stringify(index.map(e => e.url === entry.url ? change(structuredClone(e)) : e));
  assert.equal((await collect('isolated checksum', altered(e => ({ ...e, url: 'https://outside.test/' })))).status, 'invalid_target');
  assert.equal((await collect('isolated checksum', altered(e => ({ ...e, url: '/missing/' })))).status, 'invalid_target');
  assert.equal((await collect('isolated checksum', altered(e => ({ ...e, url: '/redirect/' })))).status, 'invalid_target');
  assert.equal((await collect('recovery', altered(e => { e.sections[0].body = ''; return e; }))).status, 'invalid_evidence');
  html = originalHtml.replace('id="verification"', 'id="☕ 50%:a/b"');
  const special = await collect('isolated checksum', altered(e => { e.sections[0].fragment = '☕ 50%:a/b'; return e; }));
  assert.equal(special.status, 'ready', JSON.stringify(special)); assert.equal(special.citation.url, origin + entry.url + '#' + encodeURIComponent('☕ 50%:a/b'));
  html = originalHtml + '<div id="verification"></div>';
  assert.equal((await collect('isolated checksum')).status, 'invalid_target');
  html = originalHtml + '<!-- <h2 id="ghost">Fake</h2> --><script>const fake = \'<h2 id="ghost">Fake</h2>\';</script>';
  assert.equal((await collect('isolated checksum', altered(e => { e.sections[0].fragment = 'ghost'; return e; }))).status, 'invalid_target');
  html = originalHtml.replace('Restore a backup', 'Restore a newer backup');
  const mixed = await collect('isolated checksum');
  assert.equal(mixed.status, 'ready', 'address validation remains separate');
  assert.equal(mixed.pairing.status, 'mismatched');
  const newer = { version: 1, algorithm: 'sha256', digest: createHash('sha256').update(html).digest('hex') };
  html = originalHtml;
  assert.equal((await collect('isolated checksum', altered(e => ({ ...e, publication: newer })))).pairing.status, 'mismatched');
  assert.equal((await collect('isolated checksum', altered(e => { delete e.publication; return e; }))).pairing.status, 'unknown');
  assert.equal((await collect('isolated checksum', altered(e => ({ ...e, publication: { version: 2, algorithm: 'future' } })))).pairing.status, 'unknown');
  for (const binding of [null, {}, [entry.publication, newer], { ...entry.publication, digest: 'bad' }, { ...entry.publication, other: newer }]) {
    assert.equal((await collect('isolated checksum', altered(e => ({ ...e, publication: binding })))).pairing.status, 'invalid');
  }
  const raw = Buffer.from([0, 13, 10, 255, 0xc3, 0xa9]);
  assert.equal(comparePublication(raw, { version: 1, algorithm: 'sha256', digest: createHash('sha256').update(raw).digest('hex') }).status, 'matched');
  assert.equal(comparePublication(Buffer.from(raw.toString('utf8')), { version: 1, algorithm: 'sha256', digest: createHash('sha256').update(raw).digest('hex') }).status, 'mismatched');
  html = originalHtml;
  const legacy = await collect('isolated checksum', altered(e => { delete e.sections; return e; }));
  assert.equal(legacy.status, 'ready'); assert.equal(legacy.citation.url, origin + entry.url);
  await context.close();
  // Exercise the documented executable, not only its imported helper.
  const execute = query => new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [join(repository, 'examples/agent_evidence/run.mjs'), indexPath, origin, query]);
    let stdout = '', stderr = ''; child.stdout.on('data', b => stdout += b); child.stderr.on('data', b => stderr += b);
    child.on('error', reject); child.on('exit', code => resolve({ code, stdout, stderr }));
  });
  const result = await execute('isolated checksum');
  const absent = await execute('platinum');
  assert.equal(absent.code, 2, absent.stderr); assert.equal(JSON.parse(absent.stdout).status, 'no_results');
  assert.equal(result.code, 0, result.stderr); assert.equal(JSON.parse(result.stdout).citation.url, ready.citation.url);
  html = originalHtml + '<!-- host transformation -->';
  const changedArtifact = await execute('isolated checksum');
  assert.equal(changedArtifact.code, 2, changedArtifact.stderr);
  assert.equal(JSON.parse(changedArtifact.stdout).status, 'ready');
  assert.equal(JSON.parse(changedArtifact.stdout).pairing.status, 'mismatched');
  html = originalHtml;
  console.log('Agent evidence: real published index, WASM retrieval, complete passage, ambiguous/no-result abstention, canonical DOM validation, stale/fake/duplicate targets, legacy fallback and executable passed');
} finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
