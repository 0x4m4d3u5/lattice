import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = mkdtempSync(join(tmpdir(), 'lattice-js-watch-'));
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
for (const dir of ['content/posts', 'content/static', 'templates', 'data']) mkdirSync(join(root, dir), { recursive: true });
const config = join(root, 'content/lattice.conf');
const template = join(root, 'templates/page.html');
const source = join(root, 'content/posts/note.md');
const asset = join(root, 'content/static/example.txt');
const output = join(root, 'dist/posts/note/index.html');
writeFileSync(config, 'title = Watch fixture\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\noutput_dir = dist\n');
writeFileSync(join(root, 'collections.cfg'), '[posts]\ndir = content/posts\nschema = title:String\n');
writeFileSync(template, '<main><h1>{{title}}</h1>{{content}}<footer>{{site_name}}</footer></main>');
const note = text => `---\ntitle: Watch note\n---\n${text}\n`;
writeFileSync(source, note('Initial passage'));
writeFileSync(asset, 'Initial asset');

// Observe CPU only between the first completed build and the next change, so
// startup/compiler work is excluded. The preload does not replace the delay.
const metrics = join(root, 'idle-cpu.json');
const preload = join(root, 'measure.cjs');
writeFileSync(preload, `
const fs = require('node:fs');
const write = process.stdout.write.bind(process.stdout);
let pending = '', start, measured = false;
process.stdout.write = function(chunk, ...args) {
  pending += chunk.toString();
  let end;
  while ((end = pending.indexOf('\\n')) !== -1) {
    const line = pending.slice(0, end); pending = pending.slice(end + 1);
    if (!start && line.startsWith('[lattice] built ')) start = { cpu: process.cpuUsage(), time: performance.now() };
    else if (start && !measured && line.includes('change detected in ')) {
      measured = true;
      const cpu = process.cpuUsage(start.cpu);
      fs.writeFileSync(${JSON.stringify(metrics)}, JSON.stringify({ elapsedMs: performance.now() - start.time, cpuMs: (cpu.user + cpu.system) / 1000 }));
    }
  }
  return write(chunk, ...args);
};
`);

function watch(command, extra = [], interval = '100') {
  const child = spawn(process.execPath, ['--require', preload, cli, command, '--watch', '--watch-interval', interval, ...extra], {
    cwd: root, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const state = { child, log: '', exited: false, result: null };
  child.stdout.on('data', bytes => { state.log += bytes; });
  child.stderr.on('data', bytes => { state.log += bytes; });
  child.on('error', error => { state.log += error; state.exited = true; });
  state.exit = new Promise(resolve => child.on('exit', (code, signal) => {
    state.exited = true; state.result = { code, signal }; resolve(state.result);
  }));
  return state;
}
async function until(state, predicate, description) {
  const deadline = Date.now() + 15_000;
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
  assert.ok(stopped, 'Ctrl+C must stop an idle JavaScript watcher promptly');
  assert.ok(state.result.signal === 'SIGINT' || state.result.code === 130, JSON.stringify(state.result));
}
const builds = state => (state.log.match(/\[lattice\] built /g) || []).length;
let build;
let check;
let longWait;
try {
  build = watch('build');
  await until(build, () => builds(build) === 1, 'initial build');
  await delay(1_200);
  assert.equal(builds(build), 1, 'idle watcher must not rebuild unchanged files');
  writeFileSync(source, note('Edited passage'));
  await until(build, () => builds(build) === 2, 'source rebuild');
  assert.ok(readFileSync(output, 'utf8').includes('Edited passage'));
  const lastGood = readFileSync(output, 'utf8');
  await delay(250); // Let the completed build's post-run snapshot settle.
  writeFileSync(source, '---\ndescription: Missing required title\n---\nInvalid edit\n');
  await until(build, () => build.log.includes('[lattice] build failed:'), 'validation failure');
  assert.equal(readFileSync(output, 'utf8'), lastGood, 'invalid edits preserve the last good page');
  await delay(250);
  writeFileSync(source, note('Repaired passage'));
  await until(build, () => builds(build) === 3, 'repair rebuild');
  assert.ok(readFileSync(output, 'utf8').includes('Repaired passage'));
  await delay(250);
  writeFileSync(template, readFileSync(template, 'utf8') + '<aside>Template update</aside>');
  writeFileSync(config, readFileSync(config, 'utf8').replace('Watch fixture', 'Updated site'));
  writeFileSync(asset, 'Updated asset');
  await until(build, () => readFileSync(output, 'utf8').includes('Template update') && readFileSync(output, 'utf8').includes('Updated site') && readFileSync(join(root, 'dist/static/example.txt'), 'utf8') === 'Updated asset', 'template/config/static rebuild');
  await until(build, () => builds(build) >= 4, 'completed rebuild');
  await delay(250);
  await stop(build);

  const checkOutput = join(root, 'check-output');
  check = watch('check', ['-o', checkOutput]);
  await until(check, () => check.log.includes('check passed: no violations'), 'initial read-only check');
  await delay(250);
  writeFileSync(source, '---\ndescription: Missing title\n---\nCheck edit\n');
  await until(check, () => check.log.includes('check finished in'), 'watch validation diagnostic');
  assert.equal(existsSync(checkOutput), false, 'check --watch must not publish output');
  await stop(check);

  writeFileSync(source, note('Long-interval stop probe'));
  longWait = watch('build', [], '60000');
  await until(longWait, () => builds(longWait) === 1, 'long-interval initial build');
  await delay(250);
  await stop(longWait); // SIGINT must not wait for the 60-second delay to expire.

  const { elapsedMs, cpuMs } = JSON.parse(readFileSync(metrics, 'utf8'));
  assert.ok(elapsedMs >= 1_000, `idle sample too short: ${elapsedMs}ms`);
  assert.ok(cpuMs < elapsedMs * 0.5, `idle watch spent ${cpuMs.toFixed(0)}ms CPU in ${elapsedMs.toFixed(0)}ms; polling must sleep rather than spin`);
  console.log(`JavaScript watch: idle ${cpuMs.toFixed(0)}ms CPU/${elapsedMs.toFixed(0)}ms wall, source edits, validation recovery, config/template/static changes, read-only check and SIGINT passed (${root})`);
} finally {
  if (build && !build.exited) await stop(build);
  if (check && !check.exited) await stop(check);
  if (longWait && !longWait.exited) await stop(longWait);
}
