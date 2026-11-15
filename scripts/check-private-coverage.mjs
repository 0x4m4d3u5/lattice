import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, lstatSync, readlinkSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Synthetic sources only. Never descend through a symlink, even in this test's
// preservation snapshot. The builder coverage scan must not recurse either.
const root = mkdtempSync(join(tmpdir(), 'lattice-private-coverage-'));
const content = join(root, 'content'), config = join(root, 'site.cfg');
const put = (p, text) => { mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, text); };
const snapshot = p => {
  const stat = lstatSync(p);
  if (stat.isSymbolicLink()) return { link: readlinkSync(p) };
  if (stat.isDirectory()) return Object.fromEntries(readdirSync(p).sort().map(n => [n, snapshot(join(p, n))]));
  return readFileSync(p).toString('hex');
};
const note = body => `---\ntitle: Test\nvisibility: public\n---\n${body}\n`;
put(config, `title = Coverage fixture\nbase_url = /\noutput_dir = ${root}/public\ncollections_file = ${root}/collections.cfg\ntemplates_dir = ${root}/templates\nstandalone_dir = ${root}/standalone\nstatic_allowlist = []\ncontent_index_file = content-index.json\n`);
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String\n[nested]\ndir = ${content}/nested-root\nschema = title:String\n[alias]\ndir = ${content}/nested-root/.\nschema = title:String\n[external]\ndir = ${root}/external\nschema = title:String\n`);
put(join(content, 'notes/one.md'), note('Indexed lexical source.'));
put(join(content, 'index.md'), note('Home.'));
put(join(root, 'standalone/about.md'), note('About.'));
put(join(root, 'external/remote.md'), note('External configured source.'));
put(join(root, 'templates/page.html'), '<html><body>{{content}}</body></html>');
const unknown = ['notes/NESTED_PATH_CANARY', 'UNCONFIGURED_PATH_CANARY', 'nested-root/DEEPER_PATH_CANARY'];
for (const child of unknown) put(join(content, child, 'hidden.md'), '---\ninvalid metadata\nNESTED_BODY_CANARY');
put(join(root, 'standalone/STANDALONE_PATH_CANARY/hidden.md'), 'not imported');
put(join(root, 'external/EXTERNAL_PATH_CANARY/hidden.md'), 'not imported');
put(join(content, 'static/intentional/asset.md'), 'static is not a source root');
put(join(content, 'data/intentional/ignored.md'), 'data is not a source root');
// Cycles/aliases must produce a boundary warning, never recursive traversal.
symlinkSync(content, join(content, 'LOOP_PATH_CANARY'));
symlinkSync(join(root, 'absent'), join(content, 'DANGLING_PATH_CANARY'));
const before = snapshot(root);
const sourcePaths = [content, join(root, 'standalone'), join(root, 'external'), join(root, 'templates'), config, join(root, 'collections.cfg')];
const sourceBefore = sourcePaths.map(snapshot);
const cli = process.env.LATTICE_NATIVE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const executable = process.env.LATTICE_NATIVE_CLI ? cli : process.execPath;
const prefix = process.env.LATTICE_NATIVE_CLI ? [] : [cli];
const run = (command, audience, output, json = true) => {
  const r = spawnSync(executable, [...prefix, command, content, '-c', config, '-o', output, ...(audience ? ['--audience', audience] : []), ...(command === 'check' ? [] : ['--fresh-output']), ...(json && command !== 'build' ? ['--format', 'json'] : [])], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(r.error); assert.equal(r.status, 0, r.stdout + r.stderr); return r;
};
const privateOut = join(root, 'private-export');
const inventory = JSON.parse(run('inventory', 'private', privateOut).stdout);
assert.equal(inventory.ready, true);
const warnings = inventory.diagnostics.filter(d => d.code === 'private_source_coverage');
assert.equal(warnings.length, 7, JSON.stringify(warnings));
assert.equal(new Set(warnings.map(d => d.path)).size, warnings.length);
for (const warning of warnings) {
  assert.equal(warning.severity, 'warning');
  assert.match(warning.message, /coverage is incomplete/);
  assert.match(warning.message, /nested Markdown may be omitted/);
}
const checked = JSON.parse(run('check', 'private', privateOut).stdout);
assert.deepEqual(checked.violations, []);
assert.equal(checked.messages.filter(m => m.includes('private source coverage')).length, 7);
assert.match(run('check', 'private', privateOut, false).stdout, /NESTED_PATH_CANARY/);
assert.deepEqual(snapshot(root), before, 'read-only previews changed input');
const built = run('build', 'private', privateOut);
assert.match(built.stdout + built.stderr, /private source coverage/);
const index = JSON.parse(readFileSync(join(privateOut, 'content-index.json'), 'utf8'));
assert.ok(index.some(p => p.body.includes('Indexed lexical source')));
assert.ok(!JSON.stringify(index).includes('NESTED_BODY_CANARY'));
for (const audience of ['public', null]) {
  const output = join(root, audience ?? 'default-export');
  const preview = JSON.parse(run('inventory', audience, output).stdout);
  assert.ok(!preview.diagnostics.some(d => d.code === 'private_source_coverage'));
  const checked = JSON.parse(run('check', audience, output).stdout);
  assert.equal('messages' in checked, false);
  const result = run('build', audience, output);
  assert.ok(!(result.stdout + result.stderr).includes('PATH_CANARY'));
  const walk = p => { for (const n of readdirSync(p)) { const f = join(p, n); if (lstatSync(f).isDirectory()) walk(f); else assert.doesNotMatch(readFileSync(f, 'utf8'), /PATH_CANARY|NESTED_BODY_CANARY/); } };
  walk(output);
}
assert.deepEqual(sourcePaths.map(snapshot), sourceBefore, 'build changed configured inputs');
console.log('Private source coverage: nonrecursive advisory boundaries, overlapping roots, external sources, symlink/cycle non-traversal, JSON messages and public/default isolation passed');
