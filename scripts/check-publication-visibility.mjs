import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

// Synthetic content only. Failed preparation must not alter any old artifact,
// even if it is now stale/private: rejection is not a takedown mechanism.
const root = mkdtempSync(join(tmpdir(), 'lattice-publication-visibility-'));
const content = join(root, 'content');
const output = join(root, 'dist');
const config = join(root, 'site.cfg');
const cli = process.env.LATTICE_NATIVE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const executable = process.env.LATTICE_NATIVE_CLI ? cli : process.execPath;
const prefix = process.env.LATTICE_NATIVE_CLI ? [] : [cli];
const put = (path, text) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, text); };
put(config, `title = Visibility fixture\nbase_url = https://example.test\ncollections_file = ${root}/collections.cfg\ncontent_index_file = content-index.json\ntemplates_dir = ${root}/templates\n`);
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String,type:Optional[String],publish:Optional[Bool]\n[external]\ndir = ${root}/external\nschema = title:String\n`);
put(join(root, 'templates/page.html'), '<article>{{content}}</article>');
mkdirSync(join(content, 'data'), { recursive: true });
const note = (fields = '', body = 'Public body.') => `---\ntitle: Fixture\n${fields}---\n${body}\n`;
const sources = ['notes/guide.md', 'standalone/about.md', 'index.md', '404.md', 'notes.md'].map(p => join(content, p));
sources.push(join(root, 'external/outside.md'));
for (const path of sources) put(path, note());
const source = sources[0];
const legacy = join(content, 'notes/legacy.md');
put(legacy, note('type: private\npublish: false\n', 'Organizational metadata is unchanged.'));
put(join(content, 'notes/draft.md'), note('visibility: public\ndraft: true\n', 'Unfinished public work.'));
const asset = join(content, 'static/unreferenced.bin');
put(asset, Buffer.from([0, 255, 128, 1]));
const args = (cmd, flags = []) => [...prefix, cmd, content, '-o', output, '-c', config, ...flags];
const run = (cmd, flags = []) => {
  const r = spawnSync(executable, args(cmd, flags), { encoding: 'utf8', cwd: root, timeout: 30_000 });
  assert.ifError(r.error);
  return r;
};
const ok = (cmd, flags = []) => {
  const r = run(cmd, flags);
  assert.equal(r.status, 0, r.stdout + r.stderr);
  return r;
};
const snapshot = (path) => {
  if (!existsSync(path)) return null;
  const result = {};
  function walk(dir, prefix = '') {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const file = join(dir, entry.name), key = prefix + entry.name;
      if (entry.isDirectory()) { result[key + '/'] = null; walk(file, key + '/'); }
      else result[key] = [readFileSync(file).toString('base64'), statSync(file).mtimeMs];
    }
  }
  walk(path);
  return result;
};
const reject = (path, { line = 3, kind = 'publication_visibility', code = 'E015', flags = [] } = {}) => {
  for (const cmd of ['build', 'check', 'inventory']) {
    const before = snapshot(output), inputs = snapshot(content);
    const r = run(cmd, [...(cmd === 'build' ? [] : ['--format', 'json']), ...flags]);
    assert.equal(r.status, 1, `${cmd} accepted ${path}\n${r.stdout}${r.stderr}`);
    if (cmd === 'build') {
      assert.ok(r.stdout.includes(code) && r.stdout.includes(path), r.stdout);
      assert.ok(!r.stdout.includes('[build]'), 'rejected build reported a published page');
    } else {
      const report = JSON.parse(r.stdout);
      const issues = cmd === 'check' ? report.violations : report.diagnostics;
      const issue = issues.find(v => v.path === path && (cmd === 'check' ? v.kind === kind : v.code === code));
      assert.ok(issue, r.stdout);
      assert.equal(issue.line, line, r.stdout);
      if (cmd === 'inventory') {
        assert.equal(report.ready, false);
        assert.deepEqual(report.entries, []);
      }
    }
    assert.deepEqual(snapshot(output), before, `${cmd} changed output/cache/manifest`);
    assert.deepEqual(snapshot(content), inputs, `${cmd} changed source inputs`);
    assert.ok(!(r.stdout + r.stderr).includes('PRIVATE_BODY_SENTINEL'), 'diagnostic echoed source body');
  }
};

// Ordinary publication, not just strict builds, must fail without creating output.
put(source, note('visibility: private\n', 'PRIVATE_BODY_SENTINEL'));
reject(source);
assert.equal(existsSync(output), false);

// Keep absent/public visibility and established organizational/draft behavior.
put(source, note('visibility: public\n'));
ok('check');
assert.equal(existsSync(output), false);
const preview = JSON.parse(ok('inventory', ['--format', 'json']).stdout);
assert.ok(preview.entries.some(e => e.path === 'notes/legacy/index.html' && e.status === 'planned'));
assert.ok(preview.entries.some(e => e.path === 'notes/draft/index.html' && e.status === 'excluded'));
assert.ok(preview.entries.some(e => e.path === 'static/unreferenced.bin' && e.status === 'planned'));
for (const flags of [[], [], ['--force'], ['--drafts']]) ok('build', flags);
assert.ok(readFileSync(join(output, 'notes/draft/index.html'), 'utf8').includes('Unfinished public work.'));

// Every authored page kind, including dedicated 404, generated-overwrite sources
// and a collection outside content_dir. Drafts never override private intent.
for (const path of sources) {
  for (const draft of ['', 'draft: true\n']) {
    put(path, note(`visibility: private\n${draft}`, 'PRIVATE_BODY_SENTINEL'));
    reject(path);
    reject(path, { flags: ['--drafts'] });
  }
  put(path, note());
}

// Global typing must work even when collection schemas do not declare the key.
for (const fence of ['---', '+++']) {
  const separator = fence === '---' ? ':' : '=';
  for (const value of ['true', 'false', '1', '1.5', '2026-11-07', '["public"]', '[]', '""', '"PUBLIC"', '"unlisted"', '" public "', '"private"']) {
    put(source, `${fence}\ntitle ${separator} "Fixture"\nvisibility ${separator} ${value}\n${fence}\nPRIVATE_BODY_SENTINEL\n`);
    reject(source);
  }
  // Last-assignment-wins must not erase any declaration of private intent.
  for (const first of ['"private"', 'false', '"public"']) {
    put(source, `${fence}\ntitle ${separator} "Fixture"\nvisibility ${separator} ${first}\nvisibility ${separator} "public"\n${fence}\nPRIVATE_BODY_SENTINEL\n`);
    reject(source, { line: 4 });
  }
  put(source, `\ufeff${fence}\r\ntitle ${separator} "Fixture"\r\n# visibility ${separator} "private"\r\nvisibility ${separator} "public"\r\n${fence}\r\nPublic recovery.\r\n`);
  ok('check'); ok('build');
}
// Quoted reserved keys must not look absent, particularly on custom 404 pages
// whose renderer intentionally has no collection schema validation.
for (const path of [source, join(content, '404.md')]) {
  for (const [fence, separator] of [['---', ':'], ['+++', '=']]) {
    for (const key of ['"visibility"', "'visibility'"]) {
      put(path, `${fence}\ntitle ${separator} "Fixture"\n${key} ${separator} "private"\n${fence}\nPRIVATE_BODY_SENTINEL\n`);
      reject(path);
      for (const keys of [[key, 'visibility'], ['visibility', key], [key, key]]) {
        put(path, `${fence}\ntitle ${separator} "Fixture"\n${keys[0]} ${separator} "private"\n${keys[1]} ${separator} "public"\n${fence}\nPRIVATE_BODY_SENTINEL\n`);
        reject(path, { line: 4 });
      }
      put(path, `${fence}\ntitle ${separator} "Fixture"\n${key} ${separator} "public"\n${fence}\nPublic quoted-key recovery.\n`);
      ok('check'); ok('build'); ok('inventory');
    }
  }
  put(path, note());
}
// Empty and block-array YAML are invalid, not truthy/falsey publication consent.
for (const field of ['visibility:\n', 'visibility:\n  - public\n', 'visibility: private # comment\n']) {
  put(source, note(field, 'PRIVATE_BODY_SENTINEL'));
  reject(source);
}

// Even an unchanged warm-cache source and force/strict flags cannot bypass it.
put(source, note()); ok('build'); ok('build');
put(asset, 'PRIVATE_ASSET_SENTINEL');
put(source, note('visibility: private\n', 'PRIVATE_BODY_SENTINEL'));
const warm = snapshot(output);
for (const flags of [[], ['--force'], ['--strict-wikilinks'], ['--strict-local-links'], ['--drafts']]) {
  const r = run('build', flags);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.deepEqual(snapshot(output), warm);
}
for (const value of Object.values(snapshot(output))) {
  if (value) assert.ok(!Buffer.from(value[0], 'base64').includes(Buffer.from('PRIVATE_')));
}
// A rejected transition preserves the old public file, not a false takedown.
assert.ok(existsSync(join(output, 'notes/guide/index.html')));
put(asset, 'Public replacement asset.');
put(source, note('visibility: public\n', 'Public recovery.'));
ok('check'); ok('build'); ok('inventory');
assert.ok(readFileSync(join(output, 'notes/guide/index.html'), 'utf8').includes('Public recovery.'));

// Watch invokes the same unconditional gate, then recovers after a public repair.
if (!process.env.LATTICE_NATIVE_CLI) {
  const child = spawn(executable, args('build', ['--watch', '--watch-interval', '100']), { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  let log = '', exited = false;
  child.stdout.on('data', b => { log += b; });
  child.stderr.on('data', b => { log += b; });
  const exit = new Promise(resolve => child.on('exit', () => { exited = true; resolve(); }));
  async function until(predicate) {
    const deadline = Date.now() + 10_000;
    while (!predicate()) { assert.ok(!exited && Date.now() < deadline, log); await delay(25); }
  }
  try {
    await until(() => log.includes('[lattice] built '));
    await delay(250);
    const before = snapshot(output);
    put(source, note('visibility: private\n', 'PRIVATE_BODY_SENTINEL'));
    await until(() => log.includes('E015'));
    await delay(250);
    assert.deepEqual(snapshot(output), before);
    put(source, note('visibility: public\n', 'Public watch recovery.'));
    await until(() => (log.match(/\[lattice\] built /g) || []).length === 2);
    assert.ok(readFileSync(join(output, 'notes/guide/index.html'), 'utf8').includes('Public watch recovery.'));
  } finally {
    child.kill('SIGINT');
    if (!await Promise.race([exit.then(() => true), delay(3000).then(() => false)])) { child.kill('SIGKILL'); await exit; }
  }
}
console.log('Publication visibility: ordinary build/check/inventory, source kinds, typed/duplicate metadata, draft/cache/strict policy, preservation and recovery passed');
