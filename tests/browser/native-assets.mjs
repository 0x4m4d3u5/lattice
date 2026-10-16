import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

// Disposable synthetic assets only; the native server never serves the checkout.
const root = mkdtempSync(join(tmpdir(), 'lattice-native-assets-'));
let server, exited, lines, browser;
let stderr = '';
try {
  const site = join(root, 'site');
  mkdirSync(site);
  const wasm = Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]); // Valid empty WASM module.
  const binary = Buffer.from([0, 255, 13, 10]);
  writeFileSync(join(site, 'index.html'), '<!doctype html><body>Native asset fixture</body>');
  writeFileSync(join(site, 'probe.mjs'), 'export const answer = 42;');
  writeFileSync(join(site, 'probe.js'), 'export const answer = 7;');
  writeFileSync(join(site, 'probe.wasm'), wasm);
  writeFileSync(join(site, 'blob.bin'), binary);
  const executable = join(root, 'native-server');
  const compiled = spawnSync(process.env.CC ?? 'cc', [
    '-std=c11', '-Wall', '-Wextra', '-Werror', '-pthread',
    fileURLToPath(new URL('./native-server.c', import.meta.url)), '-o', executable,
  ], { encoding: 'utf8', timeout: 30_000 });
  assert.equal(compiled.status, 0, String(compiled.error ?? compiled.stderr));
  server = spawn(executable, [site], { stdio: ['pipe', 'pipe', 'pipe'] });
  exited = once(server, 'exit');
  server.stderr.on('data', chunk => { stderr += chunk; });
  lines = createInterface({ input: server.stdout });
  const [port] = await Promise.race([
    once(lines, 'line', { signal: AbortSignal.timeout(5_000) }),
    exited.then(([code]) => { throw new Error(`native server exited ${code}: ${stderr}`); }),
  ]);
  assert.match(port, /^\d+$/);
  const origin = `http://127.0.0.1:${port}`;
  const responses = await Promise.all(['probe.mjs?v=1', 'probe.wasm?v=1', 'probe.js', 'blob.bin'].map(async path => {
    const response = await fetch(`${origin}/${path}`, { signal: AbortSignal.timeout(5_000) });
    assert.equal(response.status, 200);
    return { type: response.headers.get('content-type'), bytes: Buffer.from(await response.arrayBuffer()) };
  }));
  const channel = process.env.LATTICE_BROWSER_CHANNEL ?? 'chromium';
  assert.ok(['chromium', 'chrome'].includes(channel));
  browser = await chromium.launch({ headless: true, chromiumSandbox: true, ...(channel === 'chrome' ? { channel } : {}) });
  const context = await browser.newContext();
  const paths = new Set(['/', '/probe.mjs', '/probe.wasm', '/probe.js', '/blob.bin']);
  await context.route('**/*', route => {
    const url = new URL(route.request().url());
    return url.origin === origin && paths.has(url.pathname) ? route.continue() : route.abort();
  });
  const page = await context.newPage();
  await page.goto(origin);
  let deadline;
  const result = await Promise.race([page.evaluate(async () => {
    const result = {};
    for (const [name, path] of [['mjs', '/probe.mjs?v=1'], ['js', '/probe.js']]) {
      try { result[name] = (await import(path)).answer; }
      catch (error) { result[name] = String(error); }
    }
    try {
      const { instance } = await WebAssembly.instantiateStreaming(fetch('/probe.wasm?v=1'));
      result.wasm = instance instanceof WebAssembly.Instance;
    } catch (error) { result.wasm = String(error); }
    return result;
  }), new Promise((_, reject) => {
    deadline = setTimeout(() => reject(new Error('native browser asset probe timed out')), 10_000);
  })]).finally(() => clearTimeout(deadline));
  assert.deepEqual(result, { mjs: 42, js: 7, wasm: true }, JSON.stringify(responses.map(response => response.type)));
  assert.deepEqual(responses.map(response => response.type), ['text/javascript; charset=utf-8', 'application/wasm', 'text/javascript; charset=utf-8', 'application/octet-stream']);
  assert.deepEqual(responses[1].bytes, wasm);
  assert.deepEqual(responses[3].bytes, binary);
  console.log(`${browser.version()}: native HTTP module imports, WASM streaming, MIME and binary controls passed (sandbox enabled)`);
} finally {
  try {
    try { await browser?.close(); }
    finally {
      if (server) {
        if (server.exitCode === null && server.signalCode === null) server.stdin.end();
        const timeout = setTimeout(() => server.kill('SIGKILL'), 5_000);
        try {
          const [code, signal] = await exited;
          assert.equal(signal, null, stderr);
          assert.equal(code, 0, stderr);
        } finally { clearTimeout(timeout); lines?.close(); }
      }
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}
