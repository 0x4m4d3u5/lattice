import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { chromium } from 'playwright';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const root = mkdtempSync(join(tmpdir(), 'lattice-js-preview-browser-'));
const site = join(root, 'wiki');
const created = spawnSync(process.execPath, [join(repo, 'scripts/create-wiki.mjs'), site], { cwd: repo, encoding: 'utf8' });
assert.equal(created.status, 0, created.stdout + created.stderr);
const socket = createServer();
await new Promise(resolve => socket.listen(0, '127.0.0.1', resolve));
const port = socket.address().port;
await new Promise(resolve => socket.close(resolve));
const cli = join(repo, '_build/js/debug/build/kurisu/lattice/cmd/main/main.js');
const server = spawn(process.execPath, [cli, 'serve', '-p', String(port)], { cwd: site, stdio: ['ignore', 'pipe', 'pipe'] });
let log = '', exited = false, browser;
server.stdout.on('data', b => { log += b; });
server.stderr.on('data', b => { log += b; });
const exit = new Promise(resolve => server.on('exit', () => { exited = true; resolve(); }));
try {
  const deadline = Date.now() + 15_000;
  while (!log.includes('[lattice] built ')) {
    assert.ok(!exited && Date.now() < deadline, log);
    await delay(30);
  }
  const channel = process.env.LATTICE_BROWSER_CHANNEL ?? 'chromium';
  browser = await chromium.launch({ headless: true, chromiumSandbox: true, ...(channel === 'chrome' ? { channel } : {}) });
  const page = await browser.newPage();
  page.on('pageerror', e => { log += '\nBrowser: ' + e.message; });
  const origin = `http://127.0.0.1:${port}`;
  await page.goto(origin + '/');
  await page.getByRole('heading', { name: 'Welcome to your wiki', exact: true }).waitFor();
  const home = join(site, 'content/index.md');
  await delay(650);
  writeFileSync(home, readFileSync(home, 'utf8') + '\n## Live preview works\n\nFresh preview content.\n');
  await page.locator('h2#live-preview-works').waitFor({ timeout: 15_000 });
  await page.goto(origin + '/static/search/');
  await page.getByRole('searchbox').fill('reproducible');
  await page.getByRole('button', { name: 'Search', exact: true }).click();
  await page.locator('#lattice-results > li').first().waitFor({ timeout: 15_000 });
  assert.ok((await page.locator('#lattice-results > li').first().innerText()).includes('Publishing'));
  console.log(`${browser.version()}: JS worker preview automatic browser reload and real wiki WASM search passed`);
} catch (error) {
  console.error(log);
  throw error;
} finally {
  await browser?.close();
  server.kill('SIGINT');
  await Promise.race([exit, delay(3000).then(() => server.kill('SIGKILL'))]);
}
