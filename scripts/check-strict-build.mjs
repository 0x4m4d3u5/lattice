import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = mkdtempSync(join(tmpdir(), 'lattice-strict-build-'));
const content = join(root, 'content');
const templates = join(root, 'templates');
const output = join(root, 'dist');
for (const dir of [content, templates, join(content, 'posts'), join(content, 'data')]) mkdirSync(dir);
const config = join(root, 'site.cfg');
const collections = join(root, 'collections.cfg');
writeFileSync(collections, `[posts]\nschema = title:String,date:Date\ndir = ${join(content, 'posts')}\n`);
writeFileSync(config, `title = Strict build\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\noutput_dir = ${output}\n`);
const template = join(templates, 'page.html');
writeFileSync(template, '<article>{{content}}</article>');
const page = (body, extra = '') => `---\ntitle: Fixture\n${extra}---\n${body}\n`;
const source = join(content, 'source.md');
const target = join(content, 'target.md');
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const run = (args = ['--strict-wikilinks']) => spawnSync(process.execPath,
  [cli, 'build', content, '-c', config, ...args], { encoding: 'utf8', timeout: 30_000 });
const ok = (r) => assert.equal(r.status, 0, r.stdout + r.stderr);
const snapshot = () => {
  const files = {};
  const walk = (dir, prefix = '') => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const name = prefix + entry.name;
      if (entry.isDirectory()) walk(join(dir, entry.name), name + '/');
      else files[name] = [readFileSync(join(dir, entry.name)).toString('base64'), statSync(join(dir, entry.name)).mtimeMs];
    }
  };
  if (existsSync(output)) walk(output);
  return files;
};
const reject = (needle) => {
  const before = snapshot();
  const result = run();
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.ok(result.stdout.includes(needle), result.stdout);
  assert.ok(result.stdout.includes(source), result.stdout);
  assert.deepEqual(snapshot(), before, 'failed strict build mutated output/cache/manifest');
};

// Failed initial publication creates no output; default build keeps its warning policy.
writeFileSync(source, page('[[Missing]]'));
writeFileSync(target, page('## Kept'));
reject('Missing');
assert.equal(existsSync(output), false);
ok(run([]));
reject('Missing'); // unchanged input/cache cannot hide a broken page link

// Valid aliases, same-page links and duplicate heading IDs publish normally.
writeFileSync(source, page('## Here\n[[#Here]] [[Target.md#Kept|friendly]] [[Target#kept-2|second]]'));
writeFileSync(target, page('## Kept\n## Kept'));
ok(run());
ok(run());
writeFileSync(target, page('## Renamed'));
reject('Kept');

// Validate actual output, not heading guesses: removed H1 and template omission fail.
writeFileSync(source, page('[[Target#Title]]'));
writeFileSync(target, page('# Title\n## Kept'));
writeFileSync(template, '<article>{{body_no_h1}}</article>');
reject('Title');
writeFileSync(source, page('[[Target#Kept]]'));
writeFileSync(template, '<article id="template-anchor">No content</article><!-- id="kept" --><script>"<h2 id=\"kept\">"</script>');
reject('Kept');
writeFileSync(source, page('[[Target#template-anchor]]'));
ok(run());

// Final generated and static outputs own their IDs, not the shadowed source.
writeFileSync(template, '<article>{{content}}</article>');
writeFileSync(join(content, 'posts.md'), page('## Authored'));
writeFileSync(join(templates, 'index.html'), '<main id="generated">{{content}}</main>');
writeFileSync(source, page('[[Posts#Authored]]'));
reject('Authored');
writeFileSync(source, page('[[Posts#generated]]'));
ok(run());
mkdirSync(join(content, 'static'));
writeFileSync(join(content, 'static.md'), page('## Authored'));
writeFileSync(join(content, 'static/index.html'), '<main id="asset">Static bytes</main>');
writeFileSync(source, page('[[Static#Authored]]'));
reject('Authored');
writeFileSync(source, page('[[Static#asset]]'));
ok(run());

// Hidden drafts do not block publication, but explicit draft publication does.
writeFileSync(template, '<article>{{content}}</article>');
writeFileSync(source, page('[[Missing]]', 'draft: true\n'));
ok(run());
const beforeDrafts = snapshot();
const drafts = run(['--strict-wikilinks', '--drafts']);
assert.equal(drafts.status, 1, drafts.stdout + drafts.stderr);
assert.deepEqual(snapshot(), beforeDrafts);
writeFileSync(source, page('[[Target#Kept]]'));
ok(run());

// Strict policy persists across watch rebuilds and permits recovery after repair.
const child = spawn(process.execPath, [cli, 'build', content, '-c', config,
  '--strict-wikilinks', '--watch', '--watch-interval', '100'], { stdio: ['ignore', 'pipe', 'pipe'] });
let log = '';
let exited = false;
child.stdout.on('data', bytes => { log += bytes; });
child.stderr.on('data', bytes => { log += bytes; });
const exit = new Promise(resolve => child.on('exit', () => { exited = true; resolve(); }));
async function until(predicate) {
  const deadline = Date.now() + 10_000;
  while (!predicate()) {
    assert.ok(!exited && Date.now() < deadline, log);
    await delay(25);
  }
}
try {
  await until(() => log.includes('[lattice] built '));
  await delay(250);
  const before = snapshot();
  writeFileSync(source, page('[[WatchMissing]]'));
  await until(() => log.includes('build failed; no successful publication'));
  assert.deepEqual(snapshot(), before);
  await delay(250);
  writeFileSync(source, page('[[Target#Kept]] Repaired watch source'));
  await until(() => (log.match(/\[lattice\] built /g) || []).length === 2);
  assert.ok(readFileSync(join(output, 'source/index.html'), 'utf8').includes('Repaired watch source'));
} finally {
  child.kill('SIGINT');
  if (!await Promise.race([exit.then(() => true), delay(3000).then(() => false)])) {
    child.kill('SIGKILL'); await exit;
  }
}
console.log('Strict build publication gate: page/fragment/cache/draft/template/watch/recovery cases passed');
