import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { chromium } from 'playwright';

const repository = new URL('../../', import.meta.url);
const root = mkdtempSync(join(tmpdir(), 'lattice-search-ui-'));
const content = join(root, 'content');
const notes = join(content, 'notes');
const output = join(root, 'dist');
const search = join(content, 'static/search');
const templates = join(root, 'templates');
for (const directory of [notes, join(content, 'static'), join(content, 'data'), templates]) mkdirSync(directory, { recursive: true });
const run = (script, args) => spawnSync(process.execPath, [fileURLToPath(new URL(script, repository)), ...args], { cwd: root, encoding: 'utf8', timeout: 30_000 });
const packaged = run('scripts/package-search.mjs', [search]);
assert.equal(packaged.status, 0, packaged.stderr);
writeFileSync(join(search, 'preserve.txt'), 'unrelated local content');
assert.notEqual(run('scripts/package-search.mjs', [search]).status, 0);
assert.equal(readFileSync(join(search, 'preserve.txt'), 'utf8'), 'unrelated local content');
writeFileSync(join(notes, 'ops.md'), '---\ntitle: Operations\ntags: [Database, Reliability]\n---\n## Recovery drills\nRestore encrypted snapshots. Verify checksums.\n\n## Garden\nWater basil.\n');
writeFileSync(join(notes, 'guide.md'), '---\ntitle: Recovery checklist\ntags: [Reliability]\n---\n## Preparation\nAssign a commander.\n');
writeFileSync(join(notes, 'priority.md'), '---\ntitle: Definition priority\n---\nTerm\n: definition\n## Priorities\n: priorityprobe\n');
writeFileSync(join(notes, 'orphan.md'), '---\ntitle: Definition boundary\n---\n: standalone marker\n\nTerm\n: glossaryprobe\n');
writeFileSync(join(notes, 'model.md'), '---\ntitle: Recovery index\ntags: [Data]\n---\n## Catalog\nKeep a catalog.\n');
writeFileSync(join(notes, 'literal.md'), '---\ntitle: Literal <img src=x>\n---\n## Display examples\n`<img src=x onerror="window.hacked=true">` is literal markup.\n');
for (const [name, tags] of [['case-a', '[Database, Équipe]'], ['case-b', '[database, équipe]'], ['case-c', '[DATABASE, ÉQUIPE]']]) {
  writeFileSync(join(notes, `${name}.md`), `---\ntitle: ${name}\ntags: ${tags}\n---\n## Tag probe\ntagprobe\n`);
}
writeFileSync(join(templates, 'page.html'), '<!doctype html><title>{{title}}</title><article>{{content}}</article>');
writeFileSync(join(templates, '404.html'), '{{content}}');
const collections = join(root, 'collections.cfg');
writeFileSync(collections, `[notes]\nschema = title:String,tags:Optional[Array[String]]\ndir = ${notes}\n`);
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Wiki\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
const built = run('_build/js/debug/build/kurisu/lattice/cmd/main/main.js', ['build', content, '-c', config, '--collections', collections]);
assert.equal(built.status, 0, built.stdout + built.stderr);
for (const name of ['index.html', 'app.js', 'worker.js', 'host.js', 'renderer.wasm']) {
  assert.deepEqual(readFileSync(join(output, 'static/search', name)), readFileSync(join(search, name)));
}
// Extend only this disposable synthetic index to exercise caller-supplied URLs
// and explicit exclusion. Normal published note entries remain untouched.
const entries = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'));
entries.push({ title: 'External', url: 'https://example.org/note/', tags: [], sections: [{ heading: '', body: 'externalpreviewprobe' }] });
entries.push({ title: 'Excluded', url: '/excluded/', tags: [], body: 'exclusionprobe', sections: [] });
for (const url of ['javascript:window.hacked=true', 'data:text/html,bad', 'http://[']) {
  entries.push({ title: 'Citation probe', url, tags: [], sections: [{ heading: 'Citation', body: 'citationprobe' }] });
}
const validIndex = JSON.stringify(entries);
const assets = new Map([
  ['/wiki/static/search/', ['static/search/index.html', 'text/html']],
  ...['app.js', 'worker.js', 'host.js'].map(name => [`/wiki/static/search/${name}`, [`static/search/${name}`, 'text/javascript']]),
  ['/wiki/static/search/renderer.wasm', ['static/search/renderer.wasm', 'application/wasm']],
  ['/notes/ops/', ['notes/ops/index.html', 'text/html']],
]);
let indexMode = 'unavailable';
let releaseFirst;
const firstRequest = new Promise(resolve => { releaseFirst = resolve; });
let indexRequests = 0;
const server = createServer(async (request, response) => {
  if (request.url === '/wiki/content-index.json') {
    if (++indexRequests === 1) await firstRequest;
    response.writeHead(indexMode === 'unavailable' ? 503 : 200, { 'Content-Type': 'application/json' });
    response.end(indexMode === 'empty' ? '[]' : indexMode === 'syntax' ? '{' : indexMode === 'excerpt' ? '[{"title":"Excerpt","url":"/","tags":[],"excerpt":"recovery"}]' : validIndex);
    return;
  }
  const asset = assets.get(request.url);
  if (!asset) { response.writeHead(404); response.end(); return; }
  response.writeHead(200, { 'Content-Type': asset[1] });
  response.end(readFileSync(join(output, asset[0])));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  const channel = process.env.LATTICE_BROWSER_CHANNEL ?? 'chromium';
  assert.ok(['chrome', 'chromium'].includes(channel));
  browser = await chromium.launch({ headless: true, chromiumSandbox: true, ...(channel === 'chrome' ? { channel } : {}) });
  const context = await browser.newContext();
  const origin = `http://127.0.0.1:${server.address().port}`;
  await context.route('**/*', route => new URL(route.request().url()).origin === origin ? route.continue() : route.abort());
  const page = await context.newPage();
  page.setDefaultTimeout(10_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  // Keep real workers/WASM; hold selected deliveries to force stale ordering.
  await page.addInitScript(() => {
    window.searchWorkers = [];
    window.heldResults = [];
    const NativeWorker = window.Worker;
    window.Worker = class extends NativeWorker {
      constructor(...args) { super(...args); window.searchWorkers.push(this); }
      addEventListener(type, callback, options) {
        super.addEventListener(type, type !== 'message' ? callback : event => {
          if (event.data.type === 'results' && window.holdNextResult) {
            window.holdNextResult = false;
            window.heldResults.push(() => callback.call(this, event));
          } else { callback.call(this, event); }
        }, options);
      }
    };
  });
  const status = async text => page.waitForFunction(expected => document.querySelector('#status').textContent === expected, text);
  const ready = () => page.waitForFunction(() => !document.querySelector('#controls').disabled);
  const query = async value => {
    await page.getByRole('searchbox', { name: 'Search notes' }).fill(value);
    await page.getByRole('button', { name: 'Search', exact: true }).click();
  };
  const complete = () => page.waitForFunction(() => document.querySelector('#results').getAttribute('aria-busy') === 'false');
  const urls = () => page.locator('#results h2 a').evaluateAll(links => links.map(link => link.getAttribute('href')));
  const unavailable = 'Search is unavailable. Retry loading search.';
  await page.goto(`${origin}/wiki/static/search/`);
  await status('Loading search…');
  assert.equal(await page.getByRole('button', { name: 'Search', exact: true }).isDisabled(), true);
  releaseFirst();
  await status(unavailable);
  for (const mode of ['excerpt', 'syntax']) {
    indexMode = mode;
    await page.getByRole('button', { name: 'Retry loading search' }).click();
    await status(unavailable);
  }
  indexMode = 'valid';
  await page.getByRole('button', { name: 'Retry loading search' }).click();
  await ready();
  assert.equal(indexRequests, 4);
  assert.deepEqual(await page.locator('#tags input').evaluateAll(inputs => inputs.map(input => input.value)),
    ['Data', 'Database', 'Reliability', 'Équipe', 'équipe']);
  await page.getByLabel('Database', { exact: true }).check();
  await query('tagprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/case-a/', '/notes/case-b/', '/notes/case-c/']);
  await page.getByLabel('Database', { exact: true }).uncheck();
  await page.getByLabel('Équipe', { exact: true }).check();
  await query('tagprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/case-a/', '/notes/case-c/']);
  await page.getByLabel('équipe', { exact: true }).check();
  await query('tagprobe'); await complete(); await status('No matching sections.');
  await page.getByLabel('Équipe', { exact: true }).uncheck();
  await query('tagprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/case-b/']);
  await page.getByLabel('équipe', { exact: true }).uncheck();

  await query('recovery'); await complete();
  const expected = ['/notes/ops/', '/notes/guide/', '/notes/model/'];
  assert.deepEqual(await urls(), expected);
  assert.equal(await page.locator('#results .section').first().textContent(), 'Recovery drills');
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), expected);
  await page.getByLabel('Database', { exact: true }).check();
  await page.getByLabel('Reliability', { exact: true }).check();
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), ['/notes/ops/']);
  await page.getByLabel('Data', { exact: true }).check();
  await query('recovery'); await complete(); await status('No matching sections.');
  for (const checkbox of await page.locator('#tags input').all()) await checkbox.uncheck();
  await page.getByLabel('Data', { exact: true }).check();
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), ['/notes/model/']);
  await page.getByLabel('Data', { exact: true }).uncheck();
  await query('priorityprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/priority/']);
  assert.equal(await page.locator('#results .section').textContent(), 'Priorities');
  await query('glossaryprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/orphan/']);
  assert.ok((await page.locator('#results .snippet').textContent()).includes(': standalone marker'));
  await query('exclusionprobe'); await complete(); await status('No matching sections.');
  await query('literal'); await complete();
  assert.ok((await page.locator('#results .snippet').textContent()).includes('<img src=x onerror="window.hacked=true">'));
  assert.equal(await page.locator('#results img, #results script').count(), 0);
  assert.equal(await page.locator('#results h2').textContent(), 'Literal <img src=x>');
  assert.equal(await page.evaluate(() => window.hacked), undefined);
  await query('citationprobe'); await complete();
  assert.deepEqual(await urls(), [null, null, null]);
  assert.equal(await page.getByRole('link').count(), 0);
  assert.equal(await page.getByRole('button', { name: /^Preview page:/ }).count(), 0);
  await query('externalpreviewprobe'); await complete();
  assert.deepEqual(await urls(), ['https://example.org/note/']);
  assert.equal(await page.getByRole('button', { name: /^Preview page:/ }).count(), 0);
  await page.evaluate(() => { window.holdNextResult = true; });
  await query('basil');
  await page.waitForFunction(() => window.heldResults.length === 1);
  await query('recovery'); await complete();
  await page.evaluate(() => window.heldResults.shift()());
  assert.deepEqual(await urls(), expected);
  await page.evaluate(() => { window.holdNextResult = true; });
  await query('basil');
  await page.waitForFunction(() => window.heldResults.length === 1);
  await query(''); await complete(); await status('Enter a query to search this wiki.');
  await page.evaluate(() => window.heldResults.shift()());
  assert.equal(await page.locator('#results li').count(), 0);
  assert.equal(indexRequests, 4); // Queries reuse the loaded index and worker.
  assert.equal(await page.evaluate(() => window.searchWorkers.length), 4);
  await page.getByLabel('Database', { exact: true }).check();
  // Real worker error followed by retry, then a stale error from the old worker.
  await page.evaluate(() => {
    window.oldWorker = window.searchWorkers.at(-1);
    window.oldWorker.dispatchEvent(new ErrorEvent('error'));
  });
  await status(unavailable);
  await page.getByRole('button', { name: 'Retry loading search' }).click(); await ready();
  await page.evaluate(() => window.oldWorker.dispatchEvent(new ErrorEvent('error')));
  assert.equal(await page.locator('#controls').isDisabled(), false);
  assert.equal(await page.getByLabel('Database', { exact: true }).isChecked(), true);
  await page.getByLabel('Database', { exact: true }).uncheck();
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), expected);
  // Read the actual published output without losing the current search.
  const preview = page.getByRole('button', { name: 'Preview page: Operations', exact: true });
  const closePreview = page.getByRole('button', { name: 'Close preview', exact: true });
  await preview.focus();
  await page.keyboard.press('Enter');
  await page.frameLocator('#reader iframe').locator('article').waitFor();
  assert.ok((await page.frameLocator('#reader iframe').locator('article').textContent()).includes('Restore encrypted snapshots.'));
  assert.equal(await page.locator('#reader iframe').getAttribute('sandbox'), '');
  assert.equal(await closePreview.evaluate(element => element === document.activeElement), true);
  assert.equal(await page.getByRole('searchbox').inputValue(), 'recovery');
  assert.deepEqual(await urls(), expected);
  const columns = await page.locator('.search-column, #reader').evaluateAll(elements => elements.map(element => element.getBoundingClientRect().toJSON()));
  assert.ok(columns[1].x >= columns[0].right);
  if (process.env.LATTICE_PREVIEW_DIR) {
    mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
    await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'reader-desktop.png'), fullPage: true });
  }
  await page.keyboard.press('Tab');
  assert.equal(await page.getByRole('link', { name: 'Open full page', exact: true }).evaluate(element => element === document.activeElement), true);
  await page.keyboard.press('Escape');
  assert.equal(await page.locator('#reader').isHidden(), true);
  assert.equal(await page.locator('#reader iframe').count(), 0);
  assert.equal(await preview.evaluate(element => element === document.activeElement), true);
  await page.setViewportSize({ width: 390, height: 844 });
  await preview.click();
  await page.frameLocator('#reader iframe').locator('article').waitFor();
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  const stacked = await page.locator('.search-column, #reader').evaluateAll(elements => elements.map(element => element.getBoundingClientRect().toJSON()));
  assert.ok(stacked[1].bottom <= stacked[0].y);
  if (process.env.LATTICE_PREVIEW_DIR) await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'reader-mobile.png'), fullPage: true });
  await closePreview.click();
  assert.equal(await preview.evaluate(element => element === document.activeElement), true);
  await preview.click();
  await query('basil'); await complete();
  assert.equal(await page.locator('#reader').isHidden(), true);
  assert.equal(await page.locator('#reader iframe').count(), 0);
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.getByRole('link', { name: 'Operations', exact: true }).click();
  assert.equal(new URL(page.url()).pathname, '/notes/ops/');
  assert.ok((await page.locator('article').textContent()).includes('Restore encrypted snapshots.'));
  await page.goBack(); await ready();
  await query('basil'); await complete();
  assert.deepEqual(await urls(), ['/notes/ops/']);
  await page.clock.install();
  await page.evaluate(() => { window.holdNextResult = true; });
  await query('recovery');
  await page.waitForFunction(() => window.heldResults.length === 1);
  await page.clock.fastForward(30_001);
  await status(unavailable);
  await page.getByRole('button', { name: 'Retry loading search' }).click(); await ready();
  await query('basil'); await complete();
  assert.deepEqual(await urls(), ['/notes/ops/']);
  await page.setViewportSize({ width: 390, height: 844 });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  indexMode = 'empty';
  await page.reload(); await ready();
  assert.equal(await page.locator('#filters').isHidden(), true);
  await query('recovery'); await complete(); await status('No matching sections.');
  assert.deepEqual(errors, []);
  console.log(`${browser.version()}: packaged published wiki search passed loading, retries, tags, DOM safety, stale replies, clearing and navigation`);
} finally {
  releaseFirst();
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
