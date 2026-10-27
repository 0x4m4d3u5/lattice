import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const root = mkdtempSync(join(tmpdir(), 'lattice-inventory-'));
const content = join(root, 'content');
const out = join(root, 'dist');
const config = join(root, 'site.cfg');
const put = (path, bytes) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, bytes); };
put(config, `title = Inventory fixture\nbase_url = https://example.test\ncollections_file = ${root}/collections.cfg\ncontent_index_file = content-index.json\n`);
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String,tags:Optional[Array[String]],draft:Optional[Bool],type:Optional[String]\n`);
mkdirSync(join(content, 'data'), { recursive: true });
const note = (title, fields = '', body = 'Text.') => `---\ntitle: ${title}\n${fields}---\n${body}\n`;
put(join(content, 'notes/public.md'), note('Public', 'tags: [Garden]\n', '## Visible heading\nHello.'));
put(join(content, 'notes/private.md'), note('Private vault type', 'type: private\n', 'Vault type is not a publication filter.'));
put(join(content, 'notes/draft.md'), note('Draft', 'draft: true\ntags: [Hidden]\n'));
put(join(content, 'index.md'), note('Home'));
put(join(content, 'notes.md'), note('Authored collection route'));
put(join(content, 'standalone/hidden.md'), note('Standalone draft', 'draft: true\n'));
put(join(content, '404.md'), note('Draft error page', 'draft: true\n'));
const assetName = 'private "café".bin';
put(join(content, 'static', assetName), Buffer.from([0, 255, 128, 13, 10]));
const hook = join(root, 'readonly.mjs');
put(hook, `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
for (const name of ['writeFileSync', 'mkdirSync', 'renameSync', 'unlinkSync', 'rmSync', 'rmdirSync', 'truncateSync', 'copyFileSync']) {
  fs[name] = () => { throw new Error('inventory attempted filesystem mutation: ' + name); };
}
const open = fs.openSync;
fs.openSync = (path, flags, ...args) => {
  if (flags !== 'r' && flags !== 0) throw new Error('inventory attempted writable open');
  return open(path, flags, ...args);
};
syncBuiltinESMExports();
`);
const run = (command, args = [], readonly = command === 'inventory') => spawnSync(process.execPath, [
  ...(readonly ? ['--import', hook] : []), cli, command, content, '-o', out, '--config', config, ...args,
], { cwd: root, encoding: 'utf8', timeout: 30_000 });
const snapshot = (dir) => {
  if (!existsSync(dir)) return null;
  const result = {};
  const walk = (path, prefix) => {
    for (const entry of readdirSync(path, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const key = prefix + entry.name;
      if (entry.isDirectory()) { result[key + '/'] = null; walk(join(path, entry.name), key + '/'); }
      else result[key] = readFileSync(join(path, entry.name)).toString('hex');
    }
  };
  walk(dir, ''); return result;
};
const inventory = (args = [], expected = 0) => {
  const before = snapshot(root);
  const result = run('inventory', ['--format', 'json', ...args]);
  assert.ifError(result.error);
  assert.equal(result.status, expected, result.stdout + result.stderr);
  const data = JSON.parse(result.stdout);
  assert.equal(data.version, 1);
  assert.equal(data.ready, expected === 0);
  assert.deepEqual(snapshot(root), before, 'inventory must not change sources, output, cache, manifest or directories');
  return { data, raw: result.stdout };
};
const first = inventory();
assert.equal(existsSync(out), false);
assert.equal(inventory().raw, first.raw, 'repeated preview is deterministic');
const rows = first.data.entries;
const find = (path, status, kind) => rows.find(row => row.path === path && row.status === status && row.kind === kind);
assert.ok(find('notes/public/index.html', 'planned', 'page'));
assert.ok(find('notes/private/index.html', 'planned', 'page'), 'private vault type does not exclude publication');
assert.match(find('notes/draft/index.html', 'excluded', 'page').reason, /draft/);
assert.ok(find('hidden/index.html', 'excluded', 'page'));
assert.ok(find('404.html', 'excluded', 'page'));
assert.ok(find('404.html', 'planned', 'generated'));
assert.match(find('notes/index.html', 'excluded', 'page').reason, /superseded/);
assert.ok(find('notes/index.html', 'planned', 'generated'));
assert.equal(find('static/' + assetName, 'planned', 'static_asset').source, join(content, 'static', assetName));
assert.ok(find('.lattice-cache', 'planned', 'build_metadata'));
assert.ok(find('.lattice-manifest.json', 'planned', 'build_metadata'));
assert.ok(find('content-index.json', 'planned', 'generated'));
assert.match(first.data.notice, /not.*privacy guarantee/i);
const withDrafts = inventory(['--drafts']).data;
assert.ok(withDrafts.entries.some(row => row.path === 'notes/draft/index.html' && row.status === 'planned'));
assert.ok(withDrafts.entries.some(row => row.path === '404.html' && row.status === 'planned' && row.kind === 'page'));
assert.ok(!withDrafts.entries.some(row => /draft.*excluded/.test(row.reason)));
const text = run('inventory');
assert.equal(text.status, 0, text.stdout + text.stderr);
assert.match(text.stdout, /Publication inventory: prepared/);
assert.ok(text.stdout.includes(JSON.stringify('static/' + assetName)));
// Final output files must equal the preview's final planned paths.
let built = run('build', ['--force']); assert.equal(built.status, 0, built.stdout + built.stderr);
assert.deepEqual(Object.keys(snapshot(out)).filter(path => !path.endsWith('/')).sort(), rows.filter(row => row.status === 'planned').map(row => row.path).sort());
const warm = inventory();
assert.ok(warm.data.entries.some(row => row.path === 'style.css' && row.status === 'excluded' && /retained/.test(row.reason)));
assert.equal(warm.raw, inventory().raw);
// Static output replaces an authored page without changing publication policy.
put(config, readFileSync(config, 'utf8') + 'static_dir = notes\n');
put(join(content, 'notes/public/index.html'), 'static replacement');
const overwritten = inventory().data.entries;
assert.ok(overwritten.some(row => row.path === 'notes/public/index.html' && row.kind === 'page' && row.status === 'excluded'));
assert.ok(overwritten.some(row => row.path === 'notes/public/index.html' && row.kind === 'static_asset' && row.status === 'planned'));
// Restore only fixture configuration; schema failure suppresses partial inventory.
put(config, readFileSync(config, 'utf8').replace('static_dir = notes\n', ''));
put(join(content, 'notes/bad.md'), '---\ndraft: true\n---\nInvalid even when excluded.\n');
let blocked = inventory([], 1).data;
assert.deepEqual(blocked.entries, []);
assert.ok(blocked.diagnostics.some(d => d.severity === 'error' && /title/.test(d.message)));
put(join(content, 'notes/bad.md'), note('Repaired'));
// Inventory retains build's warning policy rather than silently becoming check.
put(join(content, 'notes/bad.md'), note('Warning page', '', '[[missing-note]]'));
const warned = inventory().data;
assert.ok(warned.diagnostics.some(d => d.severity === 'warning' && /missing-note/.test(d.message)));
assert.equal(run('check', ['--format', 'json'], true).status, 1);
put(join(content, 'notes/bad.md'), note('Repaired'));
// Existing destination shape conflict is detected without writing anything.
put(join(out, 'notes/bad'), 'blocking file');
blocked = inventory([], 1).data;
assert.deepEqual(blocked.entries, []);
assert.ok(blocked.diagnostics.some(d => /preflight/.test(d.message)));
// Setup errors use the same JSON envelope, with no stray progress output.
put(config, 'title = Missing base URL\n');
blocked = inventory([], 1).data;
assert.equal(blocked.output_dir, null);
assert.deepEqual(blocked.entries, []);
assert.ok(blocked.diagnostics.some(d => /base_url/.test(d.message)));
console.log('Publication inventory: final ownership, drafts, vault types, assets, metadata, deterministic JSON/text, build parity, blocked plans and read-only execution passed (' + root + ')');
