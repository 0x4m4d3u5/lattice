import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync, renameSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = mkdtempSync(join(tmpdir(), 'lattice-watch-pages-'));
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const content = join(root, 'content');
const output = join(content, 'generated');
const config = join(content, 'lattice.conf');
for (const dir of ['content/posts', 'templates', 'data']) mkdirSync(join(root, dir), { recursive: true });
writeFileSync(config, 'title = Watch pages\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\ncontent_index_file = content-index.json\noutput_dir = content/generated\n');
writeFileSync(join(root, 'collections.cfg'), '[posts]\ndir = content/posts\nschema = title:String\n');
for (const name of ['page.html', 'index.html', '404.html']) writeFileSync(join(root, 'templates', name), '<main>{{content}}</main>');
const note = (title, text) => `---\ntitle: ${title}\n---\n${text}\n`;
const home = join(content, 'index.md');
writeFileSync(home, note('Home', 'Initial home'));
writeFileSync(join(content, 'posts/entry.md'), note('Collection entry', 'Existing collection'));

function watch(command, extra = []) {
  const child = spawn(process.execPath, [cli, command, '--watch', '--watch-interval', '100', ...extra], {
    cwd: root, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const state = { child, log: '', exited: false };
  child.stdout.on('data', bytes => { state.log += bytes; });
  child.stderr.on('data', bytes => { state.log += bytes; });
  child.on('error', error => { state.log += error; state.exited = true; });
  state.exit = new Promise(resolve => child.on('exit', () => { state.exited = true; resolve(); }));
  return state;
}
async function until(state, predicate, description) {
  const deadline = Date.now() + 10_000;
  while (!predicate()) {
    assert.equal(state.exited, false, `watch exited waiting for ${description}\n${state.log}`);
    assert.ok(Date.now() < deadline, `timed out waiting for ${description}\n${state.log}`);
    await delay(25);
  }
}
async function stop(state) {
  if (state.exited) return;
  state.child.kill('SIGINT');
  const stopped = await Promise.race([state.exit.then(() => true), delay(3_000).then(() => false)]);
  if (!stopped) { state.child.kill('SIGKILL'); await state.exit; }
  assert.ok(stopped, 'watch must stop promptly');
}
const builds = state => (state.log.match(/\[lattice\] built /g) || []).length;
const html = path => readFileSync(join(output, path), 'utf8');
const indexed = () => JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8')).map(page => page.title);
let build;
let check;
async function change(action, description) {
  // The watcher's post-build snapshot must settle before the next author edit.
  await delay(250);
  const before = builds(build);
  action();
  await until(build, () => builds(build) > before, description);
}
try {
  build = watch('build');
  await until(build, () => builds(build) === 1, 'initial build');
  await change(() => writeFileSync(home, note('Home', 'Updated home')), 'root index edit');
  assert.ok(html('index.html').includes('Updated home'));
  const added = join(content, 'about.MD');
  await change(() => writeFileSync(added, note('About', 'New root page')), 'new uppercase root Markdown');
  assert.ok(html('about/index.html').includes('New root page'));
  const renamed = join(content, 'renamed.Md');
  await change(() => renameSync(added, renamed), 'root rename');
  assert.ok(html('renamed/index.html').includes('New root page'));
  assert.ok(existsSync(join(output, 'about/index.html')), 'watch must not introduce stale-output deletion');
  await change(() => unlinkSync(renamed), 'root removal');
  assert.ok(!indexed().includes('About'));
  await change(() => writeFileSync(join(content, '404.md'), note('Not found', 'Custom error page')), '404 creation');
  assert.ok(html('404.html').includes('Custom error page'));

  const standalone = join(content, 'standalone');
  const standaloneNote = join(standalone, 'outside.md');
  await change(() => {
    mkdirSync(standalone);
    writeFileSync(standaloneNote, note('Standalone', 'New standalone page'));
  }, 'previously missing standalone directory');
  assert.ok(html('outside/index.html').includes('New standalone page'));
  await change(() => writeFileSync(standaloneNote, note('Standalone', 'Edited standalone page')), 'standalone edit');
  assert.ok(html('outside/index.html').includes('Edited standalone page'));

  const external = join(root, 'external notes'); mkdirSync(external);
  const externalNote = join(external, 'remote.MD');
  writeFileSync(externalNote, note('External standalone', 'External page'));
  await change(() => writeFileSync(config, readFileSync(config, 'utf8') + 'standalone_dir = external notes\n'), 'standalone directory configuration');
  assert.ok(indexed().includes('External standalone'));
  assert.ok(!indexed().includes('Standalone'));
  await change(() => writeFileSync(externalNote, note('External standalone', 'Updated external page')), 'new configured standalone watch root');
  assert.ok(html('remote/index.html').includes('Updated external page'));
  await delay(250);
  const settled = builds(build);
  mkdirSync(join(content, 'not-collected'));
  writeFileSync(join(content, 'not-collected/ignored.md'), note('Ignored', 'Nested non-source'));
  writeFileSync(join(content, 'notes.txt'), 'Not Markdown');
  writeFileSync(join(output, 'unrelated.html'), 'Generated output is not a source');
  writeFileSync(standaloneNote, note('Old standalone', 'No longer configured'));
  await delay(700);
  assert.equal(builds(build), settled, 'output, nested/non-Markdown files and former standalone directory must not trigger rebuilds');
  await stop(build);

  const checkOutput = join(root, 'check-output');
  check = watch('check', ['-o', checkOutput]);
  await until(check, () => check.log.includes('check passed: no violations'), 'initial check');
  await delay(250);
  writeFileSync(home, note('Home', '[[missing-target]]'));
  await until(check, () => check.log.includes('check finished in'), 'root wikilink diagnostic');
  assert.ok(check.log.includes('missing-target'));
  await delay(250);
  writeFileSync(home, note('Home', 'Repaired root'));
  await until(check, () => (check.log.match(/check passed: no violations/g) || []).length === 2, 'root check recovery');
  await delay(250);
  writeFileSync(externalNote, note('External standalone', '[[missing-external-target]]'));
  await until(check, () => check.log.includes('missing-external-target'), 'standalone check diagnostic');
  assert.equal(existsSync(checkOutput), false, 'check --watch must remain read-only');
  await stop(check);
  console.log(`Watch pages: root/404 and standalone add/edit/rename/remove, missing/configured directories, output isolation, check diagnostics/recovery and no writes passed (${root})`);
} finally {
  if (build && !build.exited) await stop(build);
  if (check && !check.exited) await stop(check);
}
