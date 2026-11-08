import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = mkdtempSync(join(tmpdir(), 'lattice-watch-retention-'));
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
for (const dir of ['content/posts', 'content/static', 'content/data', 'templates']) mkdirSync(join(root, dir), { recursive: true });
const config = join(root, 'content/lattice.conf');
const source = join(root, 'content/posts/note.md');
const template = join(root, 'templates/page.html');
const asset = join(root, 'content/static/example.txt');
// Nest output inside a recursive collection watch root, with lexical aliases.
const output = join(root, 'content/posts/generated/posts/note/index.html');
writeFileSync(config, 'title = Initial site\nbase_url = https://example.test\ntemplates_dir = templates\ncollections_file = collections.cfg\noutput_dir = ./content/posts/../posts/generated\n');
writeFileSync(join(root, 'collections.cfg'), '[posts]\ndir = content/posts\nschema = title:String\n');
writeFileSync(source, '---\ntitle: Note\n---\nInitial body\n');
writeFileSync(template, '<main>{{content}}<footer>{{site_name}}</footer></main>');
writeFileSync(asset, 'Initial asset');
mkdirSync(join(root, 'next-templates'));
writeFileSync(join(root, 'next-templates/page.html'), '<main>{{content}}<aside>New root template</aside></main>');
const nextSource = join(root, 'next-notes'); mkdirSync(nextSource);
writeFileSync(join(nextSource, 'remote.md'), '---\ntitle: Remote\n---\nInitial remote body\n');
const nextOutput = join(root, 'content/posts/generated-next/remote/index.html');
const preload = join(root, 'edit-at-completion.cjs');
// Execute author edits inside the child, after its output is complete but
// before run_once returns. There is no scheduling race or timing assumption.
writeFileSync(preload, `
const fs = require('node:fs');
const write = process.stdout.write.bind(process.stdout);
let pending = '', builds = 0;
process.stdout.write = function(chunk, ...args) {
  pending += chunk.toString();
  let end;
  while ((end = pending.indexOf('\\n')) !== -1) {
    const line = pending.slice(0, end); pending = pending.slice(end + 1);
    if (line.startsWith('[lattice] built ')) {
      builds++;
      if (builds === 1) fs.writeFileSync(${JSON.stringify(source)}, '---\\ntitle: Note\\n---\\nRetained initial edit\\n');
      if (builds === 2) {
        fs.appendFileSync(${JSON.stringify(template)}, '<aside>Retained template</aside>');
        fs.writeFileSync(${JSON.stringify(config)}, fs.readFileSync(${JSON.stringify(config)}, 'utf8').replace('Initial site', 'Retained site'));
        fs.writeFileSync(${JSON.stringify(asset)}, 'Retained asset');
      }
      if (builds === 3) {
        const html = fs.readFileSync(${JSON.stringify(output)}, 'utf8');
        if (!html.includes('Retained template') || !html.includes('Retained site') || fs.readFileSync(${JSON.stringify(asset)}, 'utf8') !== 'Retained asset') throw Error('dependency edits were lost');
        fs.writeFileSync(${JSON.stringify(source)}, '---\\ndescription: Missing title\\n---\\nInvalid edit\\n');
      }
      if (builds === 4) fs.writeFileSync(${JSON.stringify(config)}, fs.readFileSync(${JSON.stringify(config)}, 'utf8').replace('templates_dir = templates', 'templates_dir = next-templates').replace('posts/generated', 'posts/generated-next') + 'standalone_dir = next-notes\\n');
      if (builds === 5) fs.writeFileSync(${JSON.stringify(join(nextSource, 'remote.md'))}, '---\\ntitle: Remote\\n---\\nRetained new root edit\\n');
    }
    if (line.startsWith('[lattice] build failed:')) {
      fs.writeFileSync(${JSON.stringify(source)}, '---\\ntitle: Note\\n---\\nRetained recovery\\n');
    }
  }
  return write(chunk, ...args);
};
`);
const child = spawn(process.execPath, ['--require', preload, cli, 'build', '--watch', '--watch-interval', '50'], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
let log = '', exited = false;
child.stdout.on('data', data => { log += data; });
child.stderr.on('data', data => { log += data; });
const exit = new Promise(resolve => child.on('exit', () => { exited = true; resolve(); }));
try {
  const deadline = Date.now() + 10_000;
  while (!log.includes('[lattice] built ') || !existsSync(nextOutput) || !readFileSync(nextOutput, 'utf8').includes('Retained new root edit')) {
    assert.ok(!exited && Date.now() < deadline, `edits made at build completion must not be discarded\n${log}`);
    await delay(25);
  }
  assert.ok(log.includes('[lattice] build failed:'), 'exercise failed rebuild recovery');
  assert.ok(readFileSync(nextOutput, 'utf8').includes('New root template'));
  assert.ok(readFileSync(join(root, 'content/posts/generated-next/posts/note/index.html'), 'utf8').includes('Retained recovery'));
  assert.equal(readFileSync(join(root, 'content/posts/generated-next/static/example.txt'), 'utf8'), 'Retained asset');
  const settled = (log.match(/\[lattice\] built /g) || []).length;
  await delay(500);
  assert.equal((log.match(/\[lattice\] built /g) || []).length, settled, `generated output must not cause rebuild loops\n${log}`);
  assert.ok(settled >= 6 && settled <= 7, `only input/root transitions may rebuild\n${log}`);
  console.log(`Watch retains initial/rebuild/failure edits and changed roots/output without loops (${root})`);
} finally {
  if (!exited) child.kill('SIGINT');
  const stopped = await Promise.race([exit.then(() => true), delay(3_000).then(() => false)]);
  if (!stopped) { child.kill('SIGKILL'); await exit; }
  assert.ok(stopped, 'watch must stop promptly');
}

// Check mode never publishes, so even output equal to the input root must not
// exclude sources. Edit at both successful and failed check completion.
const checkPreload = join(root, 'edit-at-check.cjs');
writeFileSync(checkPreload, `
const fs = require('node:fs');
const write = process.stdout.write.bind(process.stdout);
let pending = '', passed = 0;
process.stdout.write = function(chunk, ...args) {
  pending += chunk.toString();
  let end;
  while ((end = pending.indexOf('\\n')) !== -1) {
    const line = pending.slice(0, end); pending = pending.slice(end + 1);
    if (line.startsWith('[lattice] check passed:')) {
      passed++;
      if (passed === 1) fs.writeFileSync(${JSON.stringify(source)}, '---\\ndescription: Missing title\\n---\\nInvalid check edit\\n');
    }
    if (line.startsWith('[lattice] check finished in')) fs.writeFileSync(${JSON.stringify(source)}, '---\\ntitle: Note\\n---\\nRetained check recovery\\n');
  }
  return write(chunk, ...args);
};
`);
const checkedOutput = readFileSync(nextOutput, 'utf8');
const checker = spawn(process.execPath, ['--require', checkPreload, cli, 'check', '--watch', '--watch-interval', '50', '-o', '.'], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
let checkLog = '', checkExited = false;
checker.stdout.on('data', data => { checkLog += data; });
checker.stderr.on('data', data => { checkLog += data; });
const checkExit = new Promise(resolve => checker.on('exit', () => { checkExited = true; resolve(); }));
try {
  const deadline = Date.now() + 10_000;
  while ((checkLog.match(/check passed: no violations/g) || []).length < 2) {
    assert.ok(!checkExited && Date.now() < deadline, `check must retain completion/failure edits\n${checkLog}`);
    await delay(25);
  }
  assert.ok(checkLog.includes('check finished in'));
  assert.equal(readFileSync(nextOutput, 'utf8'), checkedOutput, 'check must not publish output');
  assert.equal(existsSync(join(root, '.lattice-cache')), false, 'check must not write a cache');
  console.log('Watch check retains completion/failure edits, including overlapping output');
} finally {
  if (!checkExited) checker.kill('SIGINT');
  const stopped = await Promise.race([checkExit.then(() => true), delay(3_000).then(() => false)]);
  if (!stopped) { checker.kill('SIGKILL'); await checkExit; }
  assert.ok(stopped, 'check watch must stop promptly');
}
for (const outputRoot of ['content/posts', '.']) {
  const rejected = spawnSync(process.execPath, [cli, 'build', '--watch', '-o', outputRoot], { cwd: root, encoding: 'utf8', timeout: 3_000 });
  assert.equal(rejected.status, 1, rejected.stdout + rejected.stderr);
  assert.match(rejected.stdout + rejected.stderr, /watch output directory contains an input root/);
}
console.log('Publishing watcher rejects output that would hide an input root');
