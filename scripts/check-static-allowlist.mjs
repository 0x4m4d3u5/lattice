import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

// Synthetic source tree only. The allowlist selects new writes, never deletes
// existing output and never authorizes publication from a mixed/private vault.
const root = mkdtempSync(join(tmpdir(), 'lattice-static-allowlist-'));
const content = join(root, 'content');
const config = join(root, 'site.cfg');
const cli = process.env.LATTICE_NATIVE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const executable = process.env.LATTICE_NATIVE_CLI ? cli : process.execPath;
const prefix = process.env.LATTICE_NATIVE_CLI ? [] : [cli];
let output = join(root, 'dist');
let guardReads = false;
const put = (path, text) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, text); };
const note = (title, fields = '', body = 'Public body.') => `---\ntitle: ${title}\n${fields}---\n${body}\n`;
const configText = (policy = '', staticDir = 'static') => `title = Static allowlist fixture\nbase_url = https://example.test\ncollections_file = ${root}/collections.cfg\ncontent_index_file = content-index.json\nstatic_dir = ${staticDir}\n${policy}`;
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String,draft:Optional[Bool]\n`);
put(join(content, 'notes/public.md'), note('Public'));
put(join(content, 'notes/draft.md'), note('Draft', 'draft: true\n', '![unpublished](/static/withheld.bin)'));
mkdirSync(join(content, 'data'), { recursive: true });
const assetBytes = Buffer.from([0, 255, 128, 13, 10, 1]);
const withheld = 'WITHHELD_ATTACHMENT_BODY_SENTINEL';
const unusual = 'downloads/café notes.pdf';
put(join(content, 'static/public.png'), assetBytes);
put(join(content, 'static', unusual), 'Explicit unreferenced asset');
put(join(content, 'static/withheld.bin'), withheld);
put(join(content, 'static/hidden/nested.bin'), withheld);
const readGuard = join(root, 'guard-reads.mjs');
put(readGuard, `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
const read = fs.readFileSync;
fs.readFileSync = (path, ...args) => {
  if (typeof path === 'string' && /\\/(withheld\\.bin|hidden\\/nested\\.bin|hidden\\/public\\.png)$/.test(path)) {
    process.stderr.write('Opened withheld attachment: ' + path);
    process.exit(97);
  }
  return read(path, ...args);
};
syncBuiltinESMExports();
`);
const run = (command, flags = []) => {
  const result = spawnSync(executable, [...(!process.env.LATTICE_NATIVE_CLI && guardReads ? ['--import', readGuard] : []), ...prefix, command, content, '-o', output, '-c', config, ...flags], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(result.error);
  return result;
};
const ok = (command, flags = []) => {
  const result = run(command, flags);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result;
};
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
  walk(path); return files;
};
const inventory = () => {
  const before = snapshot(root);
  const result = JSON.parse(ok('inventory', ['--format', 'json']).stdout);
  assert.equal(result.ready, true);
  assert.deepEqual(snapshot(root), before, 'inventory changed inputs or output');
  return result;
};
const reject = () => {
  for (const command of ['build', 'check', 'inventory']) {
    const before = snapshot(root);
    const result = run(command, command === 'build' ? [] : ['--format', 'json']);
    assert.equal(result.status, 1, `${command} accepted invalid allowlist\n${result.stdout}${result.stderr}`);
    if (command === 'inventory') {
      const report = JSON.parse(result.stdout);
      assert.equal(report.ready, false);
      assert.deepEqual(report.entries, []);
    }
    assert.deepEqual(snapshot(root), before, `${command} changed files after rejection`);
  }
};

// Omission is backward compatible, including unreferenced/draft-only assets.
put(config, configText());
assert.ok(inventory().entries.some(e => e.path === 'static/withheld.bin' && e.status === 'planned'));
ok('build');
assert.equal(readFileSync(join(output, 'static/withheld.bin'), 'utf8'), withheld);
const legacySnapshot = snapshot(output);
if (!process.env.LATTICE_NATIVE_CLI) {
  guardReads = true;
  assert.equal(run('inventory').status, 97, 'read guard must detect legacy attachment reads');
  guardReads = false;
}

// On a fresh output, only exact listed files are written. Referencing a file
// does not add it, and explicit inclusion does not require a reference.
output = join(root, 'selected');
guardReads = true;
put(config, configText(`static_allowlist = ${JSON.stringify(['public.png', unusual])}\n`));
const report = inventory();
for (const path of ['static/withheld.bin', 'static/hidden/nested.bin']) {
  assert.ok(report.entries.some(e => e.path === path && e.kind === 'static_asset' && e.status === 'excluded' && /allowlist/.test(e.reason)), path);
}
assert.ok(report.entries.some(e => e.path === 'static/' + unusual && e.status === 'planned'));
const beforeCheck = snapshot(root);
ok('check');
assert.deepEqual(snapshot(root), beforeCheck, 'check changed files');
assert.equal(existsSync(output), false);
ok('build');
assert.deepEqual(readFileSync(join(output, 'static/public.png')), assetBytes);
assert.equal(readFileSync(join(output, 'static', unusual), 'utf8'), 'Explicit unreferenced asset');
assert.equal(existsSync(join(output, 'static/withheld.bin')), false);
assert.equal(existsSync(join(output, 'static/hidden')), false);
for (const value of Object.values(snapshot(output))) {
  if (value !== null) assert.ok(!Buffer.from(value[0], 'hex').includes(Buffer.from(withheld)), 'withheld bytes reached output');
}
assert.deepEqual(snapshot(join(root, 'dist')), legacySnapshot, 'unrelated legacy output changed');
const firstFiles = Object.keys(snapshot(output)).filter(p => !p.endsWith('/')).sort();
assert.deepEqual(firstFiles, report.entries.filter(e => e.status === 'planned').map(e => e.path).sort());
ok('build');
ok('build', ['--force']);
assert.equal(existsSync(join(output, 'static/withheld.bin')), false);

// Wrong types, duplicates, malformed paths and nonexistent/non-file selections
// are errors in every command and preserve a previously successful output.
for (const value of ['true', '"public.png"', '[1]', '["public.png", "public.png"]', '["../private.bin"]', '["/private.bin"]', '["a//b"]', '["./public.png"]', '["public.png/"]', '["a\\\\b"]', '["missing.bin"]', '["downloads"]']) {
  put(config, configText(`static_allowlist = ${value}\n`)); reject();
}
put(config, configText('static_allowlist = []\nstatic_allowlist = ["public.png"]\n')); reject();

// Quoted spellings name the same reserved setting, never legacy copy-all.
for (const key of ['"static_allowlist"', "'static_allowlist'", '"static_allow\\u006cist"']) {
  put(config, configText(`${key} = []\n`));
  assert.ok(inventory().entries.filter(e => e.kind === 'static_asset').every(e => e.status === 'excluded'));
  put(config, configText(`static_allowlist = ["public.png"]\n${key} = []\n`)); reject();
  put(config, configText(`${key} = []\nstatic_allowlist = ["public.png"]\n`)); reject();
  put(config, configText(`${key} = false\n`)); reject();
}

// Unsupported double-quoted key escapes are visibly invalid, not ignored.
for (const key of ['"static_allow\\U0000006cist"', '"static_allowlist']) {
  put(config, configText(`${key} = []\n`)); reject();
  put(config, configText(`static_allowlist = ["public.png"]\n${key} = []\n`)); reject();
}

// Included image embeds use the filtered catalog; an omitted embed is an error,
// not permission to widen the allowlist. Raw Markdown links remain opt-in lint.
put(config, configText('static_allowlist = ["public.png"]\n'));
put(join(content, 'notes/public.md'), note('Public', '', '![[public.png]]'));
ok('check'); ok('build');
put(join(content, 'static/hidden/public.png'), withheld);
ok('check'); ok('build'); // an excluded duplicate does not make it ambiguous
put(join(content, 'notes/public.md'), note('Public', '', '![[hidden/public.png]]'));
reject();
put(join(content, 'notes/public.md'), note('Public', '', '[withheld](/static/withheld.bin)'));
const strict = run('build', ['--strict-local-links']);
assert.equal(strict.status, 1, strict.stdout + strict.stderr);
put(join(content, 'notes/public.md'), note('Public'));

// An empty list emits no static files, including under a custom static root.
output = join(root, 'empty');
put(config, configText('static_allowlist = []\n'));
ok('check'); ok('build');
assert.equal(existsSync(join(output, 'static')), false);
put(join(content, 'attachments/approved.bin'), assetBytes);
put(join(content, 'attachments/withheld.bin'), withheld);
output = join(root, 'custom');
put(config, configText('static_allowlist = ["approved.bin"]\n', 'attachments'));
ok('check'); ok('build');
assert.deepEqual(readFileSync(join(output, 'attachments/approved.bin')), assetBytes);
assert.equal(existsSync(join(output, 'attachments/withheld.bin')), false);

// Tightening selection does not claim to withdraw previously copied files.
put(config, configText('static_allowlist = []\n', 'attachments'));
ok('build');
assert.deepEqual(readFileSync(join(output, 'attachments/approved.bin')), assetBytes);
assert.ok(inventory().entries.some(e => e.path === 'attachments/approved.bin' && e.status === 'excluded'));
unlinkSync(join(content, 'attachments/approved.bin'));
ok('build');
assert.equal(existsSync(join(output, 'attachments/approved.bin')), true);

// Watch uses the same policy after changes and repairs. Its independent source
// change detection may read withheld files, so the byte-read guard is not used.
if (!process.env.LATTICE_NATIVE_CLI) {
  output = join(root, 'watched');
  put(join(content, 'attachments/approved.bin'), assetBytes);
  put(config, configText('static_allowlist = ["approved.bin"]\n', 'attachments'));
  const child = spawn(executable, [...prefix, 'build', content, '-o', output, '-c', config, '--watch', '--watch-interval', '100'], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  let log = '', exited = false;
  child.stdout.on('data', bytes => { log += bytes; });
  child.stderr.on('data', bytes => { log += bytes; });
  const exit = new Promise(resolve => child.on('exit', () => { exited = true; resolve(); }));
  async function until(predicate) {
    const deadline = Date.now() + 10_000;
    while (!predicate()) { assert.ok(!exited && Date.now() < deadline, log); await delay(25); }
  }
  const builds = () => (log.match(/\[lattice\] built /g) ?? []).length;
  try {
    await until(() => builds() >= 1);
    await delay(250);
    put(join(content, 'attachments/withheld.bin'), withheld + ' changed');
    await until(() => builds() >= 2);
    assert.equal(existsSync(join(output, 'attachments/withheld.bin')), false);
    await delay(250);
    const before = snapshot(output);
    put(config, configText('static_allowlist = ["missing.bin"]\n', 'attachments'));
    await until(() => log.includes('allowlisted static file does not exist'));
    await delay(250);
    assert.deepEqual(snapshot(output), before, 'rejected watch build changed output');
    put(config, configText('static_allowlist = []\n', 'attachments'));
    await until(() => builds() >= 3);
    assert.equal(existsSync(join(output, 'attachments/withheld.bin')), false);
    assert.deepEqual(readFileSync(join(output, 'attachments/approved.bin')), assetBytes, 'tightened watch selection does not delete old assets');
  } finally {
    child.kill('SIGINT');
    if (!await Promise.race([exit.then(() => true), delay(3000).then(() => false)])) { child.kill('SIGKILL'); await exit; }
  }
}

console.log('Static allowlist: exact typed selection, exclusions, binary bytes, source kinds, image/link policy, read-only checks, cache/force parity and explicit stale-output limits passed');
