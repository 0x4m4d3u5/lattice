import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { fenceLanguageProbe } from '../../scripts/note-cases.mjs';

const browserChannel = process.env.LATTICE_BROWSER_CHANNEL ?? 'chromium';
assert.ok(['chromium', 'chrome'].includes(browserChannel), 'unsupported browser channel');
const browserName = browserChannel === 'chrome' ? 'Google Chrome' : 'Chromium';

// Fixed routes expose only synthetic test assets, never arbitrary workspace files.
const assets = new Map([
  ['/tests/browser/worker.mjs', ['tests/browser/worker.mjs', 'text/javascript']],
  ['/examples/wasm_note/host.mjs', ['examples/wasm_note/host.mjs', 'text/javascript']],
  ['/scripts/note-cases.mjs', ['scripts/note-cases.mjs', 'text/javascript']],
  ['/scripts/search-cases.mjs', ['scripts/search-cases.mjs', 'text/javascript']],
  ['/renderer.wasm', ['_build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm', 'application/wasm']],
]);
const root = new URL('../../', import.meta.url);
const server = createServer(async (request, response) => {
  if (request.url === '/') {
    response.writeHead(200, { 'Content-Type': 'text/html' });
    response.end('<!doctype html><title>Lattice browser worker test</title>');
    return;
  }
  const asset = assets.get(request.url);
  if (!asset) { response.writeHead(404); response.end(); return; }
  try {
    const bytes = await readFile(new URL(asset[0], root));
    response.writeHead(200, { 'Content-Type': asset[1] });
    response.end(bytes);
  } catch {
    response.writeHead(500);
    response.end('test asset unavailable');
  }
});
await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
let browser;
try {
  // A fresh test-only browser/profile. Do not disable the Chromium sandbox.
  browser = await chromium.launch({
    headless: true, chromiumSandbox: true,
    ...(browserChannel === 'chrome' ? { channel: 'chrome' } : {}),
  });
  console.log(`Browser: ${browserName} ${browser.version()} (${browserChannel}, sandbox enabled)`);
  const context = await browser.newContext();
  const origin = `http://127.0.0.1:${server.address().port}`;
  await context.route('**/*', (route) => {
    if (new URL(route.request().url()).origin === origin) return route.continue();
    return route.abort();
  });
  const page = await context.newPage();
  await page.goto(origin);
  const result = await page.evaluate(() => new Promise((resolve, reject) => {
    const worker = new Worker('/tests/browser/worker.mjs', { type: 'module' });
    const timeout = setTimeout(() => {
      worker.terminate();
      reject(new Error('browser note worker timed out'));
    }, 30_000);
    worker.onmessage = ({ data }) => {
      clearTimeout(timeout);
      worker.terminate();
      resolve(data);
    };
    worker.onerror = (error) => {
      clearTimeout(timeout);
      worker.terminate();
      reject(new Error(error.message));
    };
  }));
  assert.equal(result.ok, true, result.error);
  assert.equal(result.worker, true, 'cases did not execute in a real dedicated worker');
  assert.equal(result.count, 611);
  assert.equal(result.searchCount, 130);
  // DOM inspection needs no network, including image requests.
  await context.route('**/*', route => route.abort());
  const destinations = await page.evaluate((html) => {
    const document = new DOMParser().parseFromString(html, 'text/html');
    return [...document.querySelectorAll('a, img')].map(element => ({
      tag: element.localName,
      url: element.getAttribute(element.localName === 'a' ? 'href' : 'src'),
      attributes: element.getAttributeNames().sort(),
    }));
  }, result.destinationHtml);
  assert.deepEqual(destinations, [
    { tag: 'a', url: '/doc%22data-probe=%22yes?x=%22&plus=a+b#frag', attributes: ['href'] },
    { tag: 'img', url: '/img.png%22data-probe=%22yes?x=%2F&plus=a+b#frag', attributes: ['alt', 'src'] },
    { tag: 'a', url: '/doc%22data-probe=%22yes?x=%22&plus=a+b#frag', attributes: ['href'] },
    { tag: 'img', url: '/img.png%22data-probe=%22yes?x=%2F&plus=a+b#frag', attributes: ['alt', 'src'] },
    { tag: 'a', url: 'https://example.test/a%22b?x=%22&plus=a+b#frag', attributes: ['href'] },
    { tag: 'a', url: '/wiki%22data-probe=%22yes?x=%2f&plus=a+b#frag', attributes: ['href'] },
  ]);
  const image = await page.evaluate((html) => {
    const element = new DOMParser().parseFromString(html, 'text/html').querySelector('img');
    return { alt: element?.getAttribute('alt'), attributes: element?.getAttributeNames().sort() };
  }, result.imageAltHtml);
  assert.deepEqual(image, { alt: 'He said "hello" & waved', attributes: ['alt', 'src'] });
  const fenceLanguage = await page.evaluate((html) => {
    // A live element makes accidental event attributes observable on dispatch.
    const container = document.createElement('div');
    container.innerHTML = html;
    document.body.append(container);
    try {
      const code = container.querySelector('code');
      const attributes = code.getAttributeNames().sort();
      const before = code.dataset.latticeProbe ?? null;
      code.dispatchEvent(new MouseEvent('mouseover', { bubbles: true }));
      return { language: code.getAttribute('class'), attributes, before, after: code.dataset.latticeProbe ?? null };
    } finally {
      container.remove();
    }
  }, result.fenceLanguageHtml);
  assert.deepEqual(fenceLanguage, {
    language: 'language-' + fenceLanguageProbe.language,
    attributes: ['class'], before: null, after: null,
  });
  assert.match(result.userAgent, /Chrome\//);
  console.log(`${browserName} ${browser.version()}: ${result.count} supplied-note and ${result.searchCount} retrieval comparisons passed in a reused Web Worker instance`);
  console.log(`Worker runtime: ${result.userAgent}`);
} finally {
  try {
    if (browser) await browser.close();
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}
