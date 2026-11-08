import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Synthetic releases only. This fixture never deletes an output directory.
const root = mkdtempSync(join(tmpdir(), 'lattice-fresh-output-'));
const content = join(root, 'content');
const config = join(root, 'site.cfg');
const legacy = join(root, 'legacy-dist');
const cli = process.env.LATTICE_NATIVE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const executable = process.env.LATTICE_NATIVE_CLI ? cli : process.execPath;
const prefix = process.env.LATTICE_NATIVE_CLI ? [] : [cli];
let output = legacy, guarded = false, failCss = false;
const put = (path, bytes) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, bytes); };
const note = (title, body = 'Public body.', fields = '') => `---\ntitle: ${title}\n${fields}---\n${body}\n`;
const bytes = Buffer.from([0, 255, 128, 13, 10, 1]);
const removedBody = 'REMOVED_PUBLIC_NOTE_SENTINEL';
const withdrawnAsset = 'WITHDRAWN_STATIC_BYTES_SENTINEL';
const hiddenPath = 'UNPUBLISHED_SOURCE_PATH_SENTINEL';
const supersededBody = 'SUPERSEDED_INTERMEDIATE_WRITE_SENTINEL';
const configText = (allow = ['public.png'], extra = '', staticDir = 'static') => `title = Fresh output fixture\nbase_url = https://example.test\ncollections_file = ${root}/collections.cfg\ntemplates_dir = ${root}/templates\ndata_dir = ${root}/data\nstandalone_dir = ${root}/standalone\ncontent_index_file = content-index.json\nstatic_dir = ${staticDir}\nstatic_allowlist = ${JSON.stringify(allow)}\n${extra}`;
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String,draft:Optional[Bool],aliases:Optional[Array[String]]\n[external]\ndir = ${root}/external\nschema = title:String\n`);
put(join(content, 'notes/public.md'), note('Public'));
put(join(content, 'notes/removed.md'), note('Removed', removedBody, 'aliases: [old-note]\n'));
put(join(content, 'notes', hiddenPath + '.md'), note('Hidden', 'Hidden draft body.', 'draft: true\n'));
put(join(content, 'notes.md'), note('Overwritten', 'Public overwritten body.', 'template: superseded.html\n'));
put(join(root, 'templates/superseded.html'), supersededBody + '{{content}}');
put(join(root, 'external/outside.md'), note('External'));
put(join(root, 'standalone/about.md'), note('About'));
put(join(root, 'templates/page.html'), '<article>{{content}}</article>');
mkdirSync(join(root, 'data'), { recursive: true });
put(join(content, 'static/public.png'), bytes);
put(join(content, 'static/withdrawn.bin'), withdrawnAsset);
put(config, configText(['public.png', 'withdrawn.bin']));
const hook = join(root, 'guard.mjs');
put(hook, `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
const read = fs.readFileSync, write = fs.writeFileSync;
fs.readFileSync = (path, ...args) => {
  if (typeof path === 'string' && path.startsWith(process.env.FRESH_OUTPUT_ROOT + '/') && /\\/(\\.lattice-cache|\\.lattice-manifest\\.json)$/.test(path)) {
    process.stderr.write('Opened old build metadata: ' + path); process.exit(97);
  }
  return read(path, ...args);
};
fs.writeFileSync = (path, data, ...args) => {
  if (String(data).includes(${JSON.stringify(supersededBody)})) {
    process.stderr.write('Wrote superseded intermediate output: ' + path); process.exit(98);
  }
  if (process.env.FRESH_FAIL_CSS === '1' && String(path).endsWith('/style.css')) {
    throw new Error('Synthetic CSS publication failure');
  }
  return write(path, data, ...args);
};
syncBuiltinESMExports();
`);
const run = (command, flags = []) => {
  const r = spawnSync(executable, [...(!process.env.LATTICE_NATIVE_CLI && guarded ? ['--import', hook] : []), ...prefix, command, content, '-o', output, '-c', config, ...flags], {
    cwd: root, encoding: 'utf8', timeout: 30_000,
    env: { ...process.env, FRESH_OUTPUT_ROOT: resolve(root, output), FRESH_FAIL_CSS: failCss ? '1' : '0' },
  });
  assert.ifError(r.error); return r;
};
const ok = (command, flags = []) => { const r = run(command, flags); assert.equal(r.status, 0, r.stdout + r.stderr); return r; };
const snapshot = path => {
  if (!existsSync(path)) return null;
  const files = {};
  const walk = (dir, prefix = '') => {
    for (const item of readdirSync(dir, { withFileTypes: true })) {
      const p = join(dir, item.name), key = prefix + item.name;
      if (item.isDirectory()) { files[key + '/'] = null; walk(p, key + '/'); }
      else files[key] = [readFileSync(p).toString('hex'), statSync(p).mtimeMs];
    }
  };
  if (!statSync(path).isDirectory()) return { file: readFileSync(path).toString('hex') };
  walk(path); return files;
};
const inputs = () => JSON.stringify([snapshot(content), snapshot(join(root, 'external')), snapshot(join(root, 'standalone')), snapshot(join(root, 'templates')), snapshot(join(root, 'data')), readFileSync(config, 'utf8'), readFileSync(join(root, 'collections.cfg'), 'utf8')]);
const reject = (flags = []) => {
  for (const command of ['build', 'inventory']) {
    const before = snapshot(root);
    const r = run(command, ['--fresh-output', ...(command === 'inventory' ? ['--format', 'json'] : []), ...flags]);
    assert.equal(r.status, 1, `${command} accepted unsafe fresh target ${output}\n${r.stdout}${r.stderr}`);
    if (command === 'inventory') {
      const report = JSON.parse(r.stdout);
      assert.equal(report.ready, false); assert.deepEqual(report.entries, []);
    }
    assert.deepEqual(snapshot(root), before, `${command} changed files on fresh-output rejection`);
  }
};
const preview = () => {
  const before = snapshot(root);
  const report = JSON.parse(ok('inventory', ['--fresh-output', '--format', 'json']).stdout);
  assert.equal(report.ready, true);
  assert.equal(report.entries.some(e => e.kind === 'build_metadata'), false);
  assert.deepEqual(snapshot(root), before, 'fresh inventory mutated files');
  return report;
};

// Compatibility: ordinary builds still create metadata and retain stale files.
ok('build');
assert.ok(existsSync(join(legacy, '.lattice-cache')));
assert.ok(readFileSync(join(legacy, '.lattice-manifest.json'), 'utf8').includes(hiddenPath));
assert.equal(readFileSync(join(legacy, 'static/withdrawn.bin'), 'utf8'), withdrawnAsset);
const oldRelease = snapshot(legacy);
unlinkSync(join(content, 'notes/removed.md'));
unlinkSync(join(content, 'static/withdrawn.bin'));
put(config, configText());
guarded = true;

// Refuse reuse even with --force. Do not read old metadata before refusing.
reject();
assert.deepEqual(snapshot(legacy), oldRelease);
assert.equal(run('build', ['--fresh-output', '--force']).status, 1);
for (const name of ['existing-empty', 'existing-file']) {
  output = join(root, name);
  if (name === 'existing-empty') mkdirSync(output); else put(output, 'Unowned file');
  reject();
}

if (!process.env.LATTICE_NATIVE_CLI) {
  output = join(root, 'guard-negative-control');
  assert.equal(run('build').status, 98, 'write guard must detect a superseded ordinary-build writer');
}

// A new isolated release contains precisely the fresh preview, no old bytes or
// internal metadata, and no transient superseded writer is allowed to run.
output = join(root, 'release-one');
const report = preview();
const before = inputs();
ok('build', ['--fresh-output']);
assert.equal(inputs(), before, 'fresh build changed inputs');
assert.deepEqual(snapshot(legacy), oldRelease, 'fresh build changed old release');
assert.deepEqual(readFileSync(join(output, 'static/public.png')), bytes);
const actual = snapshot(output);
assert.deepEqual(Object.keys(actual).filter(p => !p.endsWith('/')).sort(), report.entries.filter(e => e.status === 'planned').map(e => e.path).sort());
for (const name of ['.lattice-cache', '.lattice-manifest.json', 'notes/removed/index.html', 'static/withdrawn.bin']) assert.equal(existsSync(join(output, name)), false, name);
for (const data of Object.values(actual)) if (data !== null) {
  const text = Buffer.from(data[0], 'hex').toString('utf8');
  for (const sentinel of [removedBody, withdrawnAsset, hiddenPath, supersededBody]) assert.ok(!text.includes(sentinel), sentinel);
}
reject();

// Lexical source isolation also covers externally configured inputs and aliases.
for (const target of [join(content, 'release'), join(content, 'static/release'), join(root, 'templates/release'), join(root, 'data/release'), join(root, 'standalone/release'), join(root, 'external/release'), join(content, 'notes/../release'), join(root, 'site.cfg/release')]) {
  output = target; reject(); assert.equal(existsSync(output), false);
}
// Prefix siblings and normalized relative siblings are not descendants.
for (const target of [join(root, 'content-export'), 'content/../relative-export']) {
  output = target; preview(); ok('build', ['--fresh-output', '--force']);
}

// Validation failures create no target, even though old releases exist.
output = join(root, 'blocked-private');
put(join(content, 'notes/public.md'), note('Private', 'PRIVATE_CONTENT_SENTINEL', 'visibility: private\n'));
reject(); assert.equal(existsSync(output), false);
put(join(content, 'notes/public.md'), note('Public', '[[missing-note]]'));
const strict = run('build', ['--fresh-output', '--strict-wikilinks']);
assert.equal(strict.status, 1); assert.equal(existsSync(output), false);
put(join(content, 'notes/public.md'), note('Public'));

// Fresh mode reserves internal metadata filenames even for alternate writers.
output = join(root, 'reserved-metadata');
put(join(content, '.lattice-cache'), 'AUTHORED_CACHE_SENTINEL');
put(config, configText(['.lattice-cache'], '', '.')); reject();
put(config, configText(['public.png'], 'content_index_file = .lattice-manifest.json\n')); reject();
put(config, configText());

// Repeated modes cannot safely reuse a destination. Refuse the combination
// before its first build, and leave serve/check behavior unchanged.
output = join(root, 'watch-refused');
assert.equal(run('build', ['--fresh-output', '--watch']).status, 1);
assert.equal(existsSync(output), false);
for (const command of ['serve', 'dev', 'check', 'init']) {
  const before = snapshot(root);
  const rejected = run(command, ['--fresh-output']);
  assert.equal(rejected.status, 1);
  assert.match(rejected.stdout + rejected.stderr, /supported only by build and inventory/);
  assert.deepEqual(snapshot(root), before);
}
for (const command of ['build', 'inventory']) {
  assert.equal(run(command, ['--fresh-output=true']).status, 1);
  assert.equal(existsSync(output), false);
}
ok('check'); assert.equal(existsSync(output), false);

// I/O failure is not a successful complete export. The partial new directory
// remains untouched on retry; recovery uses another new destination.
if (!process.env.LATTICE_NATIVE_CLI) {
  output = join(root, 'partial-io'); failCss = true;
  const failed = run('build', ['--fresh-output']);
  assert.equal(failed.status, 1, failed.stdout + failed.stderr);
  assert.match(failed.stdout + failed.stderr, /Synthetic CSS publication failure/);
  assert.equal(existsSync(output), true);
  failCss = false; reject();
}
output = join(root, 'recovered-release'); preview(); ok('build', ['--fresh-output']);
assert.deepEqual(snapshot(legacy), oldRelease);
console.log('Fresh output: new isolated targets, no generated metadata/stale artifacts/intermediate writes, preview parity, source preservation, refusal, I/O recovery and legacy compatibility passed');
