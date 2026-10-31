import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { prepareWikiAssets } from '../../scripts/wiki-package.mjs';

const assets = new Map(await prepareWikiAssets());
const server = createServer((request, response) => {
  const name = request.url.replace(/^\/static\/search\//, '') || 'index.html';
  const body = assets.get(name);
  response.writeHead(body ? 200 : 404, { 'Content-Type': name.endsWith('.js') ? 'text/javascript' : name.endsWith('.css') ? 'text/css' : 'text/html' });
  response.end(body);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ chromiumSandbox: true, ...(process.env.LATTICE_BROWSER_CHANNEL === 'chrome' ? { channel: 'chrome' } : {}) });
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  // Control only response timing here. search.mjs exercises the real worker/WASM.
  await page.addInitScript(() => {
    window.workers = [];
    window.Worker = class extends EventTarget {
      constructor() { super(); window.workers.push(this); }
      postMessage(request) { this.request = request; }
      terminate() {}
    };
    window.respond = (type, fields = {}) => {
      const worker = window.workers.at(-1);
      worker.dispatchEvent(new MessageEvent('message', { data: { id: worker.request.id, type, ...fields } }));
    };
    window.statusChanges = [];
    new MutationObserver(() => {
      const text = document.querySelector('#lattice-status')?.textContent;
      if (text !== undefined && text !== window.statusChanges.at(-1)) window.statusChanges.push(text);
    }).observe(document, { subtree: true, childList: true, characterData: true });
  });
  await page.clock.install({ time: 0 });
  await page.clock.pauseAt(1000);
  await page.goto(`http://127.0.0.1:${server.address().port}/static/search/`);
  const status = page.locator('#lattice-status');
  const text = () => status.textContent();
  const height = () => status.evaluate(element => element.getBoundingClientRect().height);
  assert.equal(await text(), '', 'fast initialization must not paint a transient loading message');
  assert.equal(await status.getAttribute('role'), 'status');
  assert.equal(await status.getAttribute('aria-live'), 'polite');
  assert.equal(await page.locator('#lattice-controls').evaluate(element => element.disabled), true);
  assert.equal(await page.locator('#lattice-results').getAttribute('aria-busy'), 'true');
  const reserved = await height();
  await page.clock.runFor(100);
  await page.evaluate(() => window.respond('ready', { tags: [] }));
  assert.equal(await text(), 'Enter a query to search this wiki.');
  assert.equal(await height(), reserved, 'ready feedback must not move the directory');
  await page.clock.runFor(500);
  assert.equal(await page.evaluate(() => window.statusChanges.includes('Loading search…')), false);

  const submit = async () => {
    await page.getByRole('searchbox').fill('recovery');
    await page.locator('#lattice-search').evaluate(form => form.requestSubmit());
  };
  await submit(); await page.clock.runFor(100);
  await page.evaluate(() => window.respond('results', { results: [] }));
  assert.equal(await text(), 'No matching sections.');
  await page.clock.runFor(500);
  assert.equal(await page.evaluate(() => window.statusChanges.includes('Searching…')), false);
  await submit(); await page.clock.runFor(499);
  assert.equal(await text(), '');
  await page.clock.runFor(1);
  assert.equal(await text(), 'Searching…', 'slow queries still announce progress');
  assert.equal(await height(), reserved);
  await page.getByRole('searchbox').fill('');
  await page.locator('#lattice-search').evaluate(form => form.requestSubmit());
  await page.clock.runFor(1000);
  assert.equal(await text(), 'Enter a query to search this wiki.');

  await page.evaluate(() => window.workers.at(-1).dispatchEvent(new Event('error')));
  const unavailable = 'Search is unavailable. Retry loading search.';
  assert.equal(await text(), unavailable, 'failures are immediate, never delayed');
  await page.getByRole('button', { name: 'Retry loading search' }).click();
  await page.clock.runFor(499); assert.equal(await text(), '');
  await page.clock.runFor(1); assert.equal(await text(), 'Loading search…');
  assert.equal(await height(), reserved);
  await page.evaluate(() => window.respond('ready', { tags: [] }));
  await page.clock.runFor(1000);
  assert.equal(await text(), 'Enter a query to search this wiki.');
  // Restoring a query must not announce an idle prompt between load and results.
  await page.getByRole('searchbox').fill('recovery');
  await page.evaluate(() => {
    window.statusChanges = [];
    window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
  });
  await page.clock.runFor(100);
  await page.evaluate(() => window.respond('ready', { tags: [] }));
  assert.equal(await page.evaluate(() => window.workers.at(-1).request.type), 'search');
  await page.clock.runFor(100);
  await page.evaluate(() => window.respond('results', { results: [] }));
  await page.clock.runFor(1000);
  assert.deepEqual(await page.evaluate(() => window.statusChanges.filter(Boolean)), ['No matching sections.']);
  // A real timeout remains actionable, and cannot be overwritten by a UI timer.
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })));
  await page.clock.runFor(30000);
  assert.equal(await text(), unavailable);
  await page.clock.runFor(1000); assert.equal(await text(), unavailable);
  console.log('Search feedback: fast/slow initialization and queries, reserved layout, polite status, clearing, retry and timeout passed');
} finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
