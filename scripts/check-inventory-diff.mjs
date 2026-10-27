import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = mkdtempSync(join(tmpdir(), 'lattice-inventory-diff-'));
const content = join(root, 'content'), out = join(root, 'dist');
const put = (p, s) => { mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, s); };
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const config = join(root, 'site.cfg');
put(config, `title = Comparison\nbase_url = https://example.test\ncollections_file = ${root}/collections.cfg\noutput_dir = ${out}\n`);
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String,draft:Optional[Bool]\n`);
put(join(content, 'notes/guide.md'), '---\ntitle: Guide\n---\n## Setup\nHello.');
put(join(content, 'notes/draft.md'), '---\ntitle: Draft\ndraft: true\n---\nUnpublished.');
put(join(content, 'static/raw.htm'), '<p>Static HTML</p>');
put(join(content, 'static/file.bin'), 'Binary');
mkdirSync(join(content, 'data'), { recursive: true });
const invoke = (args, extra = []) => spawnSync(process.execPath, [...extra, cli, ...args], { cwd: root, encoding: 'utf8', timeout: 30000 });
const inventory = () => { const r = invoke(['inventory', content, '-c', config, '--format', 'json']); assert.equal(r.status, 0, r.stdout + r.stderr); return JSON.parse(r.stdout); };
const before = inventory();
// A collection route change naturally changes pages and generated indexes.
put(join(root, 'collections.cfg'), `[articles]\ndir = ${content}/notes\nschema = title:String,draft:Optional[Bool]\n`);
const after = inventory();
const oldFile = join(root, 'before.json'), newFile = join(root, 'after.json');
put(oldFile, JSON.stringify(before)); put(newFile, JSON.stringify(after));
const hook = join(root, 'readonly.mjs');
put(hook, `import fs from 'node:fs'; import { syncBuiltinESMExports } from 'node:module';
for (const name of ['writeFileSync','mkdirSync','renameSync','unlinkSync','rmSync','rmdirSync','truncateSync','copyFileSync']) fs[name] = () => { throw new Error('mutation: ' + name); };
const open = fs.openSync; fs.openSync = (p, flags, ...rest) => { if (flags !== 'r' && flags !== 0) throw new Error('writable open'); return open(p, flags, ...rest); }; syncBuiltinESMExports();`);
const snapshot = () => {
  const entries = {};
  const walk = (dir) => { for (const e of readdirSync(dir, { withFileTypes: true })) { const p = join(dir, e.name); if (e.isDirectory()) { entries[p] = null; walk(p); } else entries[p] = readFileSync(p).toString('hex'); } }; walk(root); return entries;
};
const compare = (expected = 0, args = ['--before', oldFile, '--after', newFile, '--format', 'json']) => {
  const start = snapshot(); const r = invoke(['inventory-diff', ...args], ['--import', hook]);
  assert.equal(r.status, expected, r.stdout + r.stderr); assert.deepEqual(snapshot(), start); return r;
};
const result = JSON.parse(compare().stdout);
assert.equal(result.scope, 'planned_html_paths'); assert.equal(result.ready, true);
assert.ok(result.removed.includes('notes/guide/index.html')); assert.ok(result.added.includes('articles/guide/index.html'));
assert.ok(result.removed.includes('notes/index.html')); assert.ok(result.added.includes('articles/index.html'));
assert.ok(!JSON.stringify(result).includes('draft/index.html'));
assert.ok(![...result.added, ...result.removed].some(p => !/\.html?$/i.test(p)));
assert.ok(!('moves' in result)); assert.equal(compare().stdout, JSON.stringify(result) + '\n');
assert.equal(existsSync(out), false);
const text = compare(0, ['--before', oldFile, '--after', newFile]).stdout;
assert.ok(text.includes('removed "notes/guide/index.html"')); assert.match(text, /contents not compared/);
const htmlPaths = (data) => data.entries.filter(e => e.status === 'planned' && e.kind !== 'build_metadata' && /\.html?$/i.test(e.path)).map(e => e.path);
assert.deepEqual(result.added, htmlPaths(after).filter(p => !htmlPaths(before).includes(p)).sort());
assert.deepEqual(result.removed, htmlPaths(before).filter(p => !htmlPaths(after).includes(p)).sort());
// Different roots, source names, ownership, order and diagnostics do not invent moves.
const reordered = structuredClone(before); reordered.output_dir = '/different/output'; reordered.entries.reverse();
for (const entry of reordered.entries) { if (entry.source) entry.source = 'changed/source.md'; if (entry.kind === 'page') entry.kind = 'static_asset'; }
reordered.extra_future_field = { ignored: true };
reordered.diagnostics.push({ severity: 'warning', message: 'snapshot warning' });
put(newFile, JSON.stringify(reordered));
const stable = JSON.parse(compare().stdout); assert.deepEqual(stable.added, []); assert.deepEqual(stable.removed, []); assert.equal(stable.after_warnings, 1);
const odd = structuredClone(before); odd.entries.push({ path: 'odd "café"\n.htm', source: null, status: 'planned', kind: 'static_asset', reason: 'fixture' });
put(newFile, JSON.stringify(odd)); assert.deepEqual(JSON.parse(compare().stdout).added, ['odd "café"\n.htm']);
assert.ok(compare(0, ['--before', oldFile, '--after', newFile]).stdout.includes(JSON.stringify('odd "café"\n.htm')));
const expanded = structuredClone(before);
for (const [path, kind, status] of [['redirect.HTML', 'generated', 'planned'], ['hidden.html', 'page', 'excluded'], ['private.html', 'build_metadata', 'planned'], ['data.json', 'static_asset', 'planned']]) expanded.entries.push({path, kind, status, source: null, reason: 'fixture'});
put(newFile, JSON.stringify(expanded)); assert.deepEqual(JSON.parse(compare().stdout).added, ['redirect.HTML']);
const empty = { ...before, entries: [] };
put(oldFile, JSON.stringify(empty)); put(newFile, JSON.stringify(empty)); assert.equal(JSON.parse(compare().stdout).unchanged, 0);
put(oldFile, '{'); assert.match(JSON.parse(compare(1).stdout).error, /^before:/);
put(oldFile, JSON.stringify(before));
for (const change of [d => d.version = 2, d => d.ready = false, d => d.entries = {}, d => d.entries.push(d.entries.find(e => e.status === 'planned')), d => d.entries[0].kind = 'unknown', d => d.entries[0].status = 'unknown', d => d.entries[0].source = 1, d => d.entries[0].path = '', d => d.diagnostics.push({ severity: 'error', message: 'blocked' })]) {
  const bad = structuredClone(before); change(bad); put(newFile, JSON.stringify(bad));
  const blocked = JSON.parse(compare(1).stdout); assert.equal(blocked.ready, false); assert.match(blocked.error, /^after:/); assert.ok(!('added' in blocked));
}
put(newFile, '{'); assert.match(JSON.parse(compare(1).stdout).error, /invalid JSON/);
assert.equal(JSON.parse(compare(1, ['--format', 'json']).stdout).ready, false);
assert.equal(JSON.parse(compare(1, ['--before', join(root, 'missing'), '--after', oldFile, '--format', 'json']).stdout).ready, false);
compare(1, ['--before', oldFile, '--after', newFile, '--format', 'xml']);
compare(1, ['--unknown']);
console.log('Inventory diff: real collection routes, exact HTML sets, stable ordering, exclusions, warnings, invalid snapshots, CLI errors and guarded nonmutation passed');
