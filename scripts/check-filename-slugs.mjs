import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const root = mkdtempSync(join(tmpdir(), 'lattice-filename-slugs-'));
try {
  const cli = process.env.LATTICE_NATIVE_CLI ?? process.execPath;
  const args = process.env.LATTICE_NATIVE_CLI ? [] :
    [resolve('_build/js/debug/build/kurisu/lattice/cmd/main/main.js')];
  const content = join(root, 'content');
  const notes = join(content, 'notes');
  const out = join(root, 'dist');
  const cfg = join(root, 'site.cfg');
  const collections = join(root, 'collections.cfg');
  mkdirSync(notes, { recursive: true });
  mkdirSync(join(content, 'data'));
  writeFileSync(cfg, `title = Slugs\nbase_url = https://example.test\ncollections_file = ${collections}\n`);
  writeFileSync(collections, `[notes]\ndir = ${notes}\nschema = title:String\n`);
  const add = (file, body = 'Text.') =>
    writeFileSync(join(notes, file), `---\ntitle: Note\n---\n${body}\n`);
  add('🚀 100%.md', '## Status\n\nReady.');
  add('Hash#mark.md');
  add('folder-note.md');
  add('hub.md', '[[🚀 100%#Status]] [[hash-mark]]');
  function run(command, ...flags) {
    const result = spawnSync(cli, [
      ...args, command, content, '-o', out, '--config', cfg, ...flags,
    ], { cwd: root, encoding: 'utf8', timeout: 30_000 });
    assert.ifError(result.error);
    return result;
  }
  function ok(command, ...flags) {
    const result = run(command, ...flags);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return result.stdout;
  }
  ok('check');
  const inventory = JSON.parse(ok('inventory', '--format', 'json'));
  for (const path of ['notes/🚀-100-/index.html', 'notes/hash-mark/index.html']) {
    assert.ok(inventory.entries.some(row => row.path === path && row.status === 'planned'));
  }
  assert.equal(existsSync(out), false);
  ok('build', '--strict-wikilinks');
  const html = readFileSync(join(out, 'notes/hub/index.html'), 'utf8');
  assert.match(html, /href="\/notes\/🚀-100-\/#status"/u);
  assert.match(html, /href="\/notes\/hash-mark\/"/);
  assert.ok(existsSync(join(out, 'notes/🚀-100-/index.html')));

  add('hub.md', '[[folder/note]]');
  const qualified = run('check');
  assert.notEqual(qualified.status, 0, 'qualified links must not alias unrelated flat filenames');

  add('hub.md');
  add('Hash-mark.md');
  const collision = run('check', '--format', 'json');
  assert.notEqual(collision.status, 0);
  assert.match(collision.stdout + collision.stderr, /duplicate.slug/i);
  console.log('Filename slugs: check, inventory, rendered links, and collision diagnostics passed');
} finally {
  rmSync(root, { recursive: true, force: true });
}
