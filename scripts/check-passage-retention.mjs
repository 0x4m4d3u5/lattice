import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { compareRetention, comparePublication, collectEvidence } from '../examples/agent_evidence/evidence.mjs';
const repo = fileURLToPath(new URL('../', import.meta.url));
const native = process.env.LATTICE_NATIVE_CLI;
const cli = native ?? process.env.LATTICE_CLI ?? join(repo, '_build/js/debug/build/kurisu/lattice/cmd/main/main.js');
const root = mkdtempSync(join(tmpdir(), 'lattice-retention-'));
const write = (path, text) => writeFileSync(join(root, path), text);
for (const dir of ['content/notes', 'content/data', 'templates']) mkdirSync(join(root, dir), { recursive: true });
write('site.cfg', 'title = Retention\nbase_url = https://example.test\ntemplates_dir = templates\ncollections_file = collections.cfg\ncontent_index_file = content-index.json\noutput_dir = dist\n');
write('collections.cfg', '[notes]\ndir = content/notes\nschema = title:String,related:Optional[Array[Ref[notes]]]\n');
write('templates/404.html', '{{content}}');
const put = (body, fields = 'related: [b]\n') => write('content/notes/a.md', `---\ntitle: a\n${fields}---\n${body}`);
const body = '# Title\n\nOpening café 🌱.\n\n## Second\n\nRetained β body.[^1]\n\n[^1]: Footnote 🌸.\n';
put(body);
write('content/notes/b.md', '---\ntitle: b\n---\n## Referrer\n\n[[a]] context.');
write('content/index.md', '---\ntitle: Home\n---\nPreamble 🌱.\n\n## Root\n\nRoot text.');
write('content/notes/draft.md', '---\ntitle: Draft\ndraft: true\n---\n## Draft\nHidden.');
const run = (flags = [], status = 0) => {
  const r = spawnSync(native ? cli : process.execPath, [...(native ? [] : [cli]), 'build', 'content', '-c', 'site.cfg', ...flags], { cwd: root, encoding: 'utf8', timeout: 60_000 });
  assert.ifError(r.error); assert.equal(r.status, status, r.stdout + r.stderr);
};
const index = () => JSON.parse(readFileSync(join(root, 'dist/content-index.json'), 'utf8'));
const page = () => index().find(e => e.url === '/notes/a/');
const html = (url = '/notes/a/') => readFileSync(join(root, 'dist', url, 'index.html'));
const hash = value => createHash('sha256').update(value).digest('hex');
const verify = expected => {
  assert.deepEqual(page().sections.map(s => !!s.retention), expected);
  for (const e of index()) for (const s of e.sections ?? []) if (s.retention) {
    const b = s.retention, bytes = html(e.url);
    assert.equal(compareRetention(bytes, { binding: b, heading: s.heading, body: s.body }).status, 'matched');
    assert.equal(b.digest, hash(bytes.subarray(b.start, b.end)));
    assert.equal(b.heading_digest, hash(s.heading)); assert.equal(b.body_digest, hash(s.body));
  }
};
try {
  // Default renderer includes complete heading/body and generated footnotes.
  run(); verify([true, true, true]);
  assert.equal(page().sections[0].retention.start, html().indexOf(Buffer.from('<h1 id="title">')));
  const initial = page().sections;
  const firstSlice = html().subarray(initial[0].retention.start, initial[0].retention.end).toString('utf8');
  assert.ok(firstSlice.startsWith('<h1 id="title">'));
  assert.ok(firstSlice.includes('Opening café 🌱.'));
  assert.equal(initial[0].retention.end, initial[1].retention.start);
  assert.equal(initial[1].retention.start, html().indexOf(Buffer.from('<h2 id="second">')));
  assert.equal(initial[1].retention.end, initial[2].retention.start);
  assert.ok(html().subarray(initial[2].retention.start, initial[2].retention.end).toString('utf8').includes('Footnote 🌸.'));
  const rootPreamble = index().find(e => e.url === '/').sections[0];
  assert.equal(rootPreamble.heading, ''); assert.ok(rootPreamble.retention);
  write('site.cfg', readFileSync(join(root, 'site.cfg'), 'utf8') + 'root_page = index\n');
  const verifyRoot = () => assert.ok(index().find(e => e.url === '/').sections.every(s => s.retention), 'canonical root origins must be recorded once');
  run(); verify([true, true, true]); verifyRoot();
  for (const template of [
    '<html><head></head><body>前 🌱{{content}}</body></html>',
    '{{reader_metadata}}{{backlinks}}{{related_notes}}<!--lattice-local-graph-->{{content}}',
    '{{content}}{{backlinks}}<!--lattice-local-graph-->{{related_notes}}{{reader_metadata}}',
  ]) {
    write('templates/page.html', template); run(); verify([true, true, true]); verifyRoot();
    const before = readFileSync(join(root, 'dist/content-index.json'));
    run(); verify([true, true, true]); assert.deepEqual(readFileSync(join(root, 'dist/content-index.json')), before);
    run(['--force']); verify([true, true, true]); assert.deepEqual(readFileSync(join(root, 'dist/content-index.json')), before);
  }
  write('templates/base.html', '<html><head></head><body>前 🌱{{body}}</body></html>');
  write('templates/part.html', '<main>{{body_no_h1}}</main>');
  write('templates/page.html', '{{layout: base.html}}{{include: part.html}}');
  run(); verify([false, true, true]); // Removed heading invalidates the entire first section.
  for (const template of ['Template only', '{{content}}{{content}}', '{{content | upper}}', '{{content}}{{content | upper}}', '{{?tag_name}}{{content}}{{/?tag_name}}', '{{layout: base.html}}{{content}}{{body_no_h1}}']) {
    write('templates/page.html', template); run(); verify([false, false, false]);
  }
  // Byte retention intentionally makes no claim about browser visibility.
  write('templates/page.html', '<!--{{content}}-->'); run(); verify([true, true, true]);
  assert.equal(page().sections[0].fragment, undefined);
  write('templates/page.html', '{{content}}');
  put('## Changed\n\nBefore.\n\n<!--lattice-local-graph-->\n\nAfter.\n\n## Kept\n\nUntouched café 🌱.');
  run(); verify([false, true]); // A substitution inside a slice invalidates it, later slices shift.
  put('## Changed\n\nBefore.\n\n<!--lattice-related-notes-->\n\nAfter.\n\n## Kept\n\nUntouched.');
  run(); verify([false, true]);
  put('## Changed\n\nBefore.\n\n</head>\n\nAfter.\n\n## Kept\n\nUntouched.');
  run(); verify([false, true]);
  put(body); run(); verify([true, true, true]);
  const section = page().sections[1], bytes = html();
  const passage = { binding: section.retention, heading: section.heading, body: section.body };
  assert.equal(compareRetention(bytes, { ...passage, body: 'Changed index body' }).status, 'mismatched');
  assert.equal(compareRetention(bytes, { ...passage, heading: 'Changed heading' }).status, 'mismatched');
  // The trusted index asserts the text-to-slice association; hashes do not authenticate it.
  assert.equal(compareRetention(bytes, { ...passage, body: 'Changed index body', binding: { ...passage.binding, body_digest: hash('Changed index body') } }).status, 'matched');
  const changed = Buffer.from(bytes); changed[section.retention.start] ^= 1;
  assert.equal(compareRetention(changed, passage).status, 'mismatched');
  assert.equal(compareRetention(bytes, {}).status, 'unknown');
  assert.equal(compareRetention(bytes, { binding: { version: 2, algorithm: 'future' } }).status, 'unknown');
  for (const patch of [{ start: -1 }, { end: 1.5 }, { extra: true }, { digest: 'bad' }, { end: section.retention.start }]) {
    assert.equal(compareRetention(bytes, { ...passage, binding: { ...passage.binding, ...patch } }).status, 'invalid');
  }
  assert.equal(compareRetention(bytes, { ...passage, binding: { ...passage.binding, end: bytes.length + 1 } }).status, 'mismatched');
  const unicodeAt = bytes.indexOf(Buffer.from('🌱'));
  assert.equal(compareRetention(bytes, { ...passage, binding: { ...passage.binding, start: unicodeAt + 1, end: unicodeAt + 4 } }).status, 'mismatched');
  const collected = await collectEvidence({ indexJson: JSON.stringify([page()]), query: 'retained', origin: 'https://example.test',
    search: async () => ({ results: [{ url: '/notes/a/', section_index: 1, section: section.heading }], error: null }),
    validateTarget: async (_url, _fragment, publication, p) => ({ ok: true, pairing: comparePublication(bytes, publication), retention: compareRetention(bytes, p) }),
  });
  assert.equal(collected.status, 'ready'); assert.equal(collected.pairing.status, 'matched'); assert.equal(collected.retention.status, 'matched');
  run(['--drafts']); assert.ok(index().find(e => e.title === 'Draft').sections[0].retention);
  write('site.cfg', readFileSync(join(root, 'site.cfg'), 'utf8') + 'static_dir = notes\n');
  mkdirSync(join(root, 'content/notes/a'), { recursive: true }); write('content/notes/a/index.html', 'Replacement');
  run(); assert.ok(index().filter(e => e.url === '/notes/a/').every(e => e.sections.length === 0));
  const stable = readFileSync(join(root, 'dist/content-index.json'));
  put(body, 'related: [missing]\n'); run([], 1); assert.deepEqual(readFileSync(join(root, 'dist/content-index.json')), stable);
  console.log('Passage retention: UTF-8 ranges/digests, complete origins, templates/layouts, final substitutions, cache, ownership and independent host states passed');
} finally { rmSync(root, { recursive: true, force: true }); }
