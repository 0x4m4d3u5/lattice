import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, symlinkSync } from 'node:fs';
import { createServer } from 'node:net';
import { request } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = mkdtempSync(join(tmpdir(), 'lattice-js-serve-'));
for (const dir of ['content/posts', 'content/static', 'templates', 'data']) mkdirSync(join(root, dir), { recursive: true });
writeFileSync(join(root, 'content/lattice.conf'), 'title = Preview\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\noutput_dir = dist\n');
writeFileSync(join(root, 'collections.cfg'), '[posts]\ndir = content/posts\nschema = title:String\n');
writeFileSync(join(root, 'templates/page.html'), '<!doctype html><html><body>{{content}}</body></html>');
const source = join(root, 'content/posts/one.md');
const note = text => `---\ntitle: Preview\n---\n${text}\n`;
writeFileSync(source, note('First preview'));
const binary = Buffer.from([0, 255, 13, 10]);
writeFileSync(join(root, 'content/static/blob.bin'), binary);
writeFileSync(join(root, 'content/static/probe.mjs'), 'export const answer = 42;');
writeFileSync(join(root, 'content/static/probe.wasm'), Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]));
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const reserve = createServer();
await new Promise(resolve => reserve.listen(0, '127.0.0.1', resolve));
const port = reserve.address().port;
await new Promise(resolve => reserve.close(resolve));
const origin = `http://127.0.0.1:${port}`;
function start() {
  const child = spawn(process.execPath, [cli, 'serve', '-p', String(port)], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  const state = { child, log: '', exited: false };
  child.stdout.on('data', b => { state.log += b; });
  child.stderr.on('data', b => { state.log += b; });
  state.exit = new Promise(resolve => child.on('exit', code => { state.exited = true; resolve(code); }));
  return state;
}
async function until(state, predicate, label) {
  const deadline = Date.now() + 15_000;
  while (!predicate()) {
    assert.ok(!state.exited && Date.now() < deadline, `${label}\n${state.log}`);
    await delay(30);
  }
}
const get = (path, options = {}) => fetch(origin + path, { signal: AbortSignal.timeout(5000), ...options });
const raw = path => new Promise((resolve, reject) => {
  const req = request(origin, { path }, res => { res.resume(); res.on('end', () => resolve(res.statusCode)); });
  req.on('error', reject); req.end();
});
const server = start();
let sse;
try {
  await until(server, () => server.log.includes('[lattice] built '), 'first build');
  let response = await get('/posts/one/');
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.ok(html.includes('First preview') && html.includes('/__lattice_reload'));
  assert.ok(!readFileSync(join(root, 'dist/posts/one/index.html'), 'utf8').includes('/__lattice_reload'), 'injection must not mutate published files');
  response = await get('/static/blob.bin?x=1');
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), binary);
  assert.match((await get('/static/probe.mjs')).headers.get('content-type'), /javascript/);
  assert.match((await get('/static/probe.wasm')).headers.get('content-type'), /application\/wasm/);
  assert.equal(await (await get('/posts/one/', { method: 'HEAD' })).text(), '');
  assert.equal((await get('/missing/')).status, 404);
  assert.equal((await get('/posts/one/', { method: 'POST' })).status, 405);
  for (const path of ['/../collections.cfg', '/%2e%2e/collections.cfg', '/%ZZ']) assert.notEqual(await raw(path), 200, path);
  writeFileSync(join(root, 'outside.txt'), 'outside sentinel');
  symlinkSync(join(root, 'outside.txt'), join(root, 'dist/escape.txt'));
  assert.notEqual((await get('/escape.txt')).status, 200);

  let events = '';
  sse = request(origin + '/__lattice_reload', res => {
    assert.match(res.headers['content-type'], /text\/event-stream/);
    res.on('data', b => { events += b; });
  });
  sse.on('error', () => {}); sse.end();
  await until(server, () => events.includes(': connected'), 'SSE connected');
  await delay(650);
  const before = events;
  writeFileSync(source, note('Second preview'));
  await until(server, () => events !== before, 'reload event');
  assert.ok((await (await get('/posts/one/')).text()).includes('Second preview'));
  await delay(650);
  const good = events;
  writeFileSync(source, '---\ntitle: 42\n---\nInvalid source\n');
  await until(server, () => server.log.includes('build failed'), 'failed edit');
  await delay(650);
  assert.equal(events, good, 'failed build must not reload browser');
  assert.ok((await (await get('/posts/one/')).text()).includes('Second preview'));
  writeFileSync(source, note('Repaired preview'));
  await until(server, () => events !== good, 'repair reload');
  assert.ok((await (await get('/posts/one/')).text()).includes('Repaired preview'));

  const occupied = start();
  const code = await Promise.race([occupied.exit, delay(8000).then(() => { occupied.child.kill('SIGKILL'); throw Error('occupied-port startup hung'); })]);
  assert.equal(code, 1, occupied.log);
  assert.ok(occupied.log.includes('failed to start dev server'));
} finally {
  sse?.destroy();
  server.child.kill('SIGINT');
  const stopped = await Promise.race([server.exit.then(() => true), delay(3000).then(() => false)]);
  if (!stopped) { server.child.kill('SIGKILL'); await server.exit; }
  assert.ok(stopped, 'SIGINT must terminate the CLI and worker promptly');
}
await assert.rejects(get('/posts/one/'));
console.log('JS serve: first build, responsive HTTP/assets, SSE edit/repair, failed-build retention, path containment, occupied port and shutdown passed');
