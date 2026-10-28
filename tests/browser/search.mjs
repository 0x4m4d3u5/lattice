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
writeFileSync(join(notes, 'ops.md'), '---\ntitle: Operations\ndescription: A field guide to restoring services with confidence. Practice the sequence, record the evidence, and leave a clearer path for the next person.\ntoc: true\ntags: [Database, Reliability]\n---\n## Recovery drills\nRestore encrypted snapshots. Verify checksums. A backup is only useful when the team knows how to bring it back. Run this exercise in an isolated training environment before you need it during an incident.\n\n> The goal is repeatability: another person should be able to follow the record and reach the same result.\n\n### Before you begin\n\n1. Choose a snapshot and record its timestamp.\n2. Confirm that the restore target is isolated from production.\n3. Assign one person to run the exercise and another to capture observations.\n\n### Verify the result\n\nCompare the restored records with the manifest. Check both totals and a small sample of individual entries; a successful process exit is only the first signal.\n\n### Leave a useful record\n\nWrite down what surprised you, which step took longest, and what you would change in the runbook. Link the evidence from the exercise so the next reader can follow the decisions.\n\n## Training sandbox\n\nThe fictional basil dataset is used for these drills. It contains no customer records.\n');
writeFileSync(join(notes, 'retired.md'), '---\ntitle: Retired note\ntags: [RetiredOnly]\n---\n<!-- No published passage remains. -->\n');
writeFileSync(join(notes, 'guide.md'), '---\ntitle: Recovery checklist\ntags: [Reliability]\n---\n## Preparation\nAssign a commander. See [[ops]] for the practice sequence.\n');
writeFileSync(join(notes, 'priority.md'), '---\ntitle: Definition priority\n---\nTerm\n: definition\n## Priorities\n: priorityprobe\n');
writeFileSync(join(notes, 'orphan.md'), '---\ntitle: Definition boundary\n---\n: standalone marker\n\nTerm\n: glossaryprobe\n');
writeFileSync(join(notes, 'model.md'), '---\ntitle: Recovery index\ntags: [Data]\n---\n## Catalog\nKeep a catalog.\n');
writeFileSync(join(notes, 'literal.md'), '---\ntitle: Literal <img src=x>\n---\n## Display examples\n`<img src=x onerror="window.hacked=true">` is literal markup.\n');
for (const [name, tags] of [['case-a', '[Database, Équipe]'], ['case-b', '[database, équipe]'], ['case-c', '[DATABASE, ÉQUIPE]']]) {
  writeFileSync(join(notes, `${name}.md`), `---\ntitle: ${name}\ntags: ${tags}\n---\n## Tag probe\ntagprobe\n`);
}
writeFileSync(join(templates, 'page.html'), readFileSync(new URL('examples/wiki_search/page.html', repository), 'utf8').replaceAll('/static/search/', '/wiki/static/search/'));
writeFileSync(join(templates, 'wiki-navigation.html'), readFileSync(new URL('examples/wiki_search/wiki-navigation.html', repository), 'utf8').replaceAll('/static/search/', '/wiki/static/search/').replace('/content-index.json', '/wiki/content-index.json'));
writeFileSync(join(templates, '404.html'), '{{content}}');
const collections = join(root, 'collections.cfg');
writeFileSync(collections, `[notes]\nschema = title:String,tags:Optional[Array[String]],description:Optional[String]\ndir = ${notes}\n`);
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Wiki\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
const built = run('_build/js/debug/build/kurisu/lattice/cmd/main/main.js', ['build', content, '-c', config, '--collections', collections]);
assert.equal(built.status, 0, built.stdout + built.stderr);
for (const name of ['index.html', 'app.js', 'worker.js', 'host.js', 'renderer.wasm', 'page.css', 'shell.css', 'catalogue.js']) {
  assert.deepEqual(readFileSync(join(output, 'static/search', name)), readFileSync(join(search, name)));
}
// Extend only this disposable synthetic index to exercise caller-supplied URLs
// and explicit exclusion. Normal published note entries remain untouched.
const entries = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'));
assert.deepEqual(entries.find(entry => entry.title === 'Retired note').sections, []);
entries.push({ title: 'Encoded fragment', url: '/encoded/', tags: [], sections: [{ heading: 'Special', body: 'encodedfragmentprobe', fragment: 'café & 100% #🌱' }] });
entries.push({ title: 'External', url: 'https://example.org/note/', tags: [], sections: [{ heading: '', body: 'externalpreviewprobe' }] });
entries.push({ title: 'Excluded', url: '/excluded/', tags: [], body: 'exclusionprobe', sections: [] });
for (const url of ['javascript:window.hacked=true', 'data:text/html,bad', 'http://[']) {
  entries.push({ title: 'Citation probe', url, tags: [], sections: [{ heading: 'Citation', body: 'citationprobe' }] });
}
entries.push({ title: 'Legacyprobe', url: '/legacy/', tags: ['Legacy'], body: '' });
// More matches than the first screen: ranking must stay stable as batches append.
for (const [term, count] of [['batchprobe', 23], ['capprobe', 55]]) {
  for (let i = 0; i < count; i++) {
    const number = String(i).padStart(2, '0');
    entries.push({ title: `Passage ${number}`, url: `/${term}/${number}/`, tags: i < 12 ? ['Data'] : [],
      sections: [{ heading: 'A matching passage', body: term, fragment: `section-${number}` }] });
  }
}
entries.push({ title: 'Non-navigation batch', url: 'javascript:void(0)', tags: [],
  sections: Array.from({ length: 11 }, (_, i) => ({ heading: `Section ${i}`, body: 'nonlinkbatchprobe' })) });
const validIndex = JSON.stringify(entries);
const changedTagIndex = JSON.stringify(entries.map(entry => ({ ...entry, tags: entry.tags.map(tag => tag.replace(/[A-Z]/g, letter => letter.toLowerCase())) })));
const assets = new Map([
  ['/wiki/static/search/', ['static/search/index.html', 'text/html']],
  ...['app.js', 'worker.js', 'host.js', 'catalogue.js'].map(name => [`/wiki/static/search/${name}`, [`static/search/${name}`, 'text/javascript']]),
  ['/wiki/static/search/renderer.wasm', ['static/search/renderer.wasm', 'application/wasm']],
  ['/wiki/static/search/shell.css', ['static/search/shell.css', 'text/css']],
  ['/wiki/static/search/page.css', ['static/search/page.css', 'text/css']],
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
    response.end(indexMode === 'casechanged' ? changedTagIndex : indexMode === 'empty' ? '[]' : indexMode === 'excluded-only' ? JSON.stringify(entries.filter(entry => entry.sections?.length === 0)) : indexMode === 'syntax' ? '{' : indexMode === 'excerpt' ? '[{"title":"Excerpt","url":"/","tags":[],"excerpt":"recovery"}]' : validIndex);
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
    window.heldReady = [];
    const NativeWorker = window.Worker;
    window.Worker = class extends NativeWorker {
      constructor(...args) { super(...args); window.searchWorkers.push(this); }
      addEventListener(type, callback, options) {
        super.addEventListener(type, type !== 'message' ? callback : event => {
          if (event.data.type === 'ready' && window.holdNextReady) {
            window.holdNextReady = false;
            window.heldReady.push(() => callback.call(this, event));
          } else if (event.data.type === 'results' && window.holdNextResult) {
            window.holdNextResult = false;
            window.heldResults.push(() => callback.call(this, event));
          } else { callback.call(this, event); }
        }, options);
      }
    };
  });
  const status = async text => page.waitForFunction(expected => document.querySelector('#lattice-status').textContent === expected, text);
  const ready = async () => {
    await page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
    if (await page.locator('#lattice-navigation').isHidden()) await page.getByRole('button', { name: 'Browse & search' }).click();
    if (await page.locator('#lattice-filters').isVisible() && !await page.locator('#lattice-filters').evaluate(element => element.open)) await page.locator('#lattice-filters summary').click();
  };
  const query = async value => {
    await page.getByRole('searchbox', { name: 'Search notes' }).fill(value);
    await page.getByRole('button', { name: 'Search', exact: true }).click();
  };
  const complete = () => page.waitForFunction(() => document.querySelector('#lattice-results').getAttribute('aria-busy') === 'false');
  const urls = () => page.locator('#lattice-results h2 a').evaluateAll(links => links.map(link => link.getAttribute('href')?.split('#')[0] ?? null));
  const unavailable = 'Search is unavailable. Retry loading search.';
  await page.goto(`${origin}/wiki/static/search/`);
  await status('Loading search…');
  assert.equal(await page.getByRole('button', { name: 'Search', exact: true }).isDisabled(), true);
  releaseFirst();
  await status(unavailable);
  for (const mode of ['excerpt', 'syntax']) {
    indexMode = mode;
    await page.getByRole('button', { name: 'Retry loading search' }).focus();
    await page.keyboard.press('Enter');
    await status(unavailable);
    assert.equal(await page.locator('#lattice-retry').evaluate(button => button === document.activeElement), true);
    assert.equal(await page.locator('#lattice-retry').getAttribute('aria-disabled'), null);
  }
  indexMode = 'valid';
  await page.evaluate(() => { window.holdNextReady = true; });
  await page.getByRole('button', { name: 'Retry loading search' }).focus();
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => window.heldReady.length === 1);
  assert.equal(await page.locator('#lattice-retry').evaluate(button => button === document.activeElement), true);
  assert.equal(await page.locator('#lattice-retry').getAttribute('aria-disabled'), 'true');
  if (process.env.LATTICE_PREVIEW_DIR) {
    mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
    await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'retry-loading-desktop.png') });
  }
  await page.keyboard.press('Enter');
  assert.equal(await page.evaluate(() => window.searchWorkers.length), 4, 'Loading retry cannot start another worker');
  await page.evaluate(() => window.heldReady.shift()());
  await page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  assert.equal(await page.getByRole('searchbox', { name: 'Search notes' }).evaluate(input => input === document.activeElement), true,
    'Successful keyboard retry should return focus to search');
  await ready();
  assert.equal(await page.getByRole('search', { name: 'Wiki search', exact: true }).count(), 1);
  assert.equal(indexRequests, 4);
  assert.deepEqual(await page.locator('#lattice-tags input').evaluateAll(inputs => inputs.map(input => input.value)),
    ['Data', 'Database', 'Legacy', 'Reliability', 'Équipe', 'équipe']);
  await page.getByLabel('Legacy', { exact: true }).check();
  await query('legacyprobe'); await complete();
  assert.deepEqual(await urls(), ['/legacy/']);
  await page.getByLabel('Legacy', { exact: true }).uncheck();
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

  const more = page.getByRole('button', { name: 'Show more results', exact: true });
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 844 }); await ready();
    await query('batchprobe'); await complete();
    assert.equal(await page.locator('#lattice-results > li').count(), 10);
    assert.equal(await more.count(), 1, 'Readers need access to matching sections after the first ten');
    assert.equal(await more.isVisible(), true);
    await page.evaluate(() => { window.firstSearchResult = document.querySelector('#lattice-results > li'); });
    await more.focus(); await more.scrollIntoViewIfNeeded();
    if (process.env.LATTICE_PREVIEW_DIR) await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, `search-more-button-${width}.png`) });
    await page.keyboard.press('Enter');
    assert.equal(await page.locator('#lattice-results > li').count(), 20);
    assert.equal(await page.evaluate(() => window.firstSearchResult === document.querySelector('#lattice-results > li')), true,
      'Showing another batch must preserve existing result nodes');
    assert.equal(await page.locator('#lattice-results h2 a').nth(10).evaluate(link => link === document.activeElement), true);
    assert.equal(await page.locator('#lattice-results h2 a').nth(10).getAttribute('href'), '/batchprobe/10/#section-10');
    if (process.env.LATTICE_PREVIEW_DIR) await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, `search-more-${width}.png`) });
    await more.focus(); await page.keyboard.press('Enter');
    assert.equal(await page.locator('#lattice-results > li').count(), 23);
    assert.deepEqual(await urls(), Array.from({ length: 23 }, (_, i) => `/batchprobe/${String(i).padStart(2, '0')}/`));
    assert.equal(await page.locator('#lattice-results h2 a').nth(20).evaluate(link => link === document.activeElement), true);
    assert.equal(await more.isHidden(), true);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await query(''); await complete();
    assert.equal(await more.isHidden(), true);
    assert.equal(await page.locator('#lattice-results > li').count(), 0);
  }
  await page.setViewportSize({ width: 1280, height: 720 }); await ready();
  await query('nonlinkbatchprobe'); await complete();
  await more.focus(); await page.keyboard.press('Enter');
  assert.equal(await page.locator('#lattice-results > li').count(), 11);
  assert.equal(await page.locator('#lattice-results > li').nth(10).evaluate(item => item === document.activeElement), true);
  assert.equal(await page.locator('#lattice-results a[href]').count(), 0);
  await query('capprobe'); await complete();
  for (let count = 20; count <= 50; count += 10) {
    await more.click();
    assert.equal(await page.locator('#lattice-results > li').count(), count);
  }
  assert.equal(await more.isHidden(), true);
  assert.match(await page.locator('#lattice-status').textContent(), /50/);
  assert.match(await page.locator('#lattice-status').textContent(), /refine/i);
  await page.getByLabel('Data', { exact: true }).check();
  await query('batchprobe'); await complete();
  assert.equal(await page.locator('#lattice-results > li').count(), 10);
  await more.click();
  assert.equal(await page.locator('#lattice-results > li').count(), 12);
  assert.equal(await more.isHidden(), true);
  await page.getByLabel('Data', { exact: true }).uncheck();
  await page.evaluate(() => { window.holdNextResult = true; });
  await query('batchprobe');
  await page.waitForFunction(() => window.heldResults.length === 1);
  assert.equal(await more.isHidden(), true, 'A new request hides the previous batch control');
  await query('notfoundprobe'); await complete();
  await page.evaluate(() => window.heldResults.shift()());
  assert.equal(await more.isHidden(), true, 'Stale results must not restore a batch control');
  assert.equal(await page.locator('#lattice-results > li').count(), 0);

  await query('recovery'); await complete();
  const expected = ['/notes/ops/', '/notes/guide/', '/notes/model/'];
  assert.deepEqual(await page.locator('#lattice-results h2 a').evaluateAll(links => links.map(link => link.getAttribute('href'))),
    ['/notes/ops/#recovery-drills', '/notes/guide/#preparation', '/notes/model/#catalog']);
  assert.deepEqual(await urls(), expected);
  assert.equal(await page.locator('#lattice-results .section').first().textContent(), 'Recovery drills');
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), expected);
  await page.getByLabel('Database', { exact: true }).check();
  await page.getByLabel('Reliability', { exact: true }).check();
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), ['/notes/ops/']);
  await page.getByLabel('Data', { exact: true }).check();
  await query('recovery'); await complete(); await status('No matching sections.');
  for (const checkbox of await page.locator('#lattice-tags input').all()) await checkbox.uncheck();
  await page.getByLabel('Data', { exact: true }).check();
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), ['/notes/model/']);
  await page.getByLabel('Data', { exact: true }).uncheck();
  await query('priorityprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/priority/']);
  assert.equal(await page.locator('#lattice-results .section').textContent(), 'Priorities');
  await query('glossaryprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/orphan/']);
  assert.ok((await page.locator('#lattice-results .snippet').textContent()).includes(': standalone marker'));
  await query('exclusionprobe'); await complete(); await status('No matching sections.');
  await query('literal'); await complete();
  assert.ok((await page.locator('#lattice-results .snippet').textContent()).includes('<img src=x onerror="window.hacked=true">'));
  assert.equal(await page.locator('#lattice-results img, #lattice-results script').count(), 0);
  assert.equal(await page.locator('#lattice-results h2').textContent(), 'Literal <img src=x>');
  assert.equal(await page.evaluate(() => window.hacked), undefined);
  await query('citationprobe'); await complete();
  assert.deepEqual(await urls(), [null, null, null]);
  assert.equal(await page.locator('#lattice-results').getByRole('link').count(), 0);
  assert.equal(await page.getByRole('button', { name: /^Read note:/ }).count(), 0);
  await query('encodedfragmentprobe'); await complete();
  assert.equal(await page.locator('#lattice-results h2 a').getAttribute('href'), `/encoded/#${encodeURIComponent('café & 100% #🌱')}`);
  await query('externalpreviewprobe'); await complete();
  assert.deepEqual(await urls(), ['https://example.org/note/']);
  assert.equal(await page.getByRole('button', { name: /^Read note:/ }).count(), 0);
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
  assert.equal(await page.locator('#lattice-results li').count(), 0);
  assert.equal(indexRequests, 4); // Queries reuse the loaded index and worker.
  assert.equal(await page.evaluate(() => window.searchWorkers.length), 4);
  await query('batchprobe'); await complete();
  assert.equal(await more.isVisible(), true);
  await page.getByLabel('Database', { exact: true }).check();
  // Real worker error followed by retry, then a stale error from the old worker.
  await page.evaluate(() => {
    window.oldWorker = window.searchWorkers.at(-1);
    window.oldWorker.dispatchEvent(new ErrorEvent('error'));
  });
  await status(unavailable);
  assert.equal(await more.isHidden(), true, 'Worker failure clears the batch control');
  await page.evaluate(() => { window.holdNextReady = true; });
  await page.getByRole('button', { name: 'Retry loading search' }).click();
  await page.waitForFunction(() => window.heldReady.length === 1);
  await page.locator('.overview-link').focus();
  await page.evaluate(() => window.heldReady.shift()());
  await page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  assert.equal(await page.locator('.overview-link').evaluate(link => link === document.activeElement), true, 'Retry must not steal focus after the reader moves away');
  await ready();
  await page.evaluate(() => window.oldWorker.dispatchEvent(new ErrorEvent('error')));
  assert.equal(await page.locator('#lattice-controls').isDisabled(), false);
  assert.equal(await page.getByLabel('Database', { exact: true }).isChecked(), true);
  await page.getByLabel('Équipe', { exact: true }).check();
  await query('tagprobe'); await complete();
  assert.deepEqual(await urls(), ['/notes/case-a/', '/notes/case-c/']);
  // A rebuilt index can choose a different display spelling for the same tag.
  indexMode = 'casechanged';
  await page.reload(); await ready(); await complete();
  assert.equal(await page.getByLabel('database', { exact: true }).isChecked(), true);
  assert.equal(await page.getByLabel('Équipe', { exact: true }).isChecked(), true);
  assert.equal(await page.getByLabel('équipe', { exact: true }).isChecked(), false);
  assert.deepEqual(await urls(), ['/notes/case-a/', '/notes/case-c/']);
  indexMode = 'valid';
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole('button', { name: 'Browse & search' }).click();
  await page.evaluate(() => window.searchWorkers.at(-1).dispatchEvent(new ErrorEvent('error')));
  await status(unavailable);
  assert.equal(await more.isHidden(), true, 'Worker failure clears the batch control');
  await page.evaluate(() => { window.holdNextReady = true; });
  await page.getByRole('button', { name: 'Retry loading search' }).focus();
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => window.heldReady.length === 1);
  if (process.env.LATTICE_PREVIEW_DIR) await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'retry-loading-mobile.png') });
  await page.keyboard.press('Escape');
  await page.evaluate(() => window.heldReady.shift()());
  await page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  assert.equal(await page.locator('#lattice-navigation-toggle').evaluate(button => button === document.activeElement), true,
    'Completing retry after mobile dismissal must not focus hidden search');
  await ready(); await complete();
  await page.setViewportSize({ width: 1280, height: 720 });
  assert.equal(await page.getByLabel('Database', { exact: true }).isChecked(), true);
  assert.equal(await page.getByLabel('Équipe', { exact: true }).isChecked(), true);
  assert.equal(await page.getByLabel('équipe', { exact: true }).isChecked(), false);
  assert.deepEqual(await urls(), ['/notes/case-a/', '/notes/case-c/']);
  await page.getByLabel('Équipe', { exact: true }).uncheck();
  await page.getByLabel('Database', { exact: true }).uncheck();
  await query('recovery'); await complete();
  assert.deepEqual(await urls(), expected);
  await page.getByLabel('Database', { exact: true }).check();
  await query('recovery'); await complete();
  const passageLink = page.locator('#lattice-results').getByRole('link', { name: 'Operations', exact: true });
  await passageLink.focus();
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  await complete();
  assert.equal(await page.locator('#lattice-filters').evaluate(element => element.open), false);
  assert.equal(await page.locator('#lattice-filters summary').textContent(), 'Filter by tags (1 selected)');
  assert.equal(await page.getByRole('button', { name: 'Clear tag filters', exact: true }).isVisible(), true);
  await ready(); await complete();
  assert.equal(await page.getByRole('searchbox').inputValue(), 'recovery');
  assert.equal(await page.getByLabel('Database', { exact: true }).isChecked(), true);
  assert.deepEqual(await urls(), ['/notes/ops/']);
  assert.equal(new URL(page.url()).pathname, '/notes/ops/');
  assert.equal(new URL(page.url()).hash, '#recovery-drills');
  assert.equal(await page.locator('article :target').getAttribute('id'), 'recovery-drills');
  await page.goBack(); await ready(); await complete();
  await page.goForward(); await ready(); await complete();
  assert.equal(new URL(page.url()).hash, '#recovery-drills');
  assert.equal(await page.locator('article :target').getAttribute('id'), 'recovery-drills');
  assert.equal(await page.getByRole('search', { name: 'Wiki search', exact: true }).count(), 1);
  assert.ok((await page.locator('article').textContent()).includes('Restore encrypted snapshots.'));
  // Restored filters stay visible even when their checkboxes are collapsed.
  await page.locator('#lattice-filters summary').click();
  if (process.env.LATTICE_PREVIEW_DIR) {
    mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
    await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'filters-desktop.png') });
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await ready();
  await page.getByLabel('Data', { exact: true }).check();
  await query('recovery'); await complete(); await status('No matching sections.');
  await page.locator('#lattice-filters summary').click();
  assert.equal(await page.locator('#lattice-filters summary').textContent(), 'Filter by tags (2 selected)');
  if (process.env.LATTICE_PREVIEW_DIR) await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'filters-mobile.png') });
  const clearFilters = page.getByRole('button', { name: 'Clear tag filters', exact: true });
  await clearFilters.focus(); await page.keyboard.press('Enter'); await complete();
  assert.deepEqual(await urls(), expected);
  assert.equal(await clearFilters.isHidden(), true);
  assert.equal(await page.locator('#lattice-filters summary').textContent(), 'Filter by tags');
  assert.equal(await page.locator('#lattice-filters').evaluate(element => element.open), false);
  assert.equal(await page.getByRole('searchbox').evaluate(element => element === document.activeElement), true);
  assert.equal(await page.getByRole('searchbox').inputValue(), 'recovery');
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  await page.reload(); await ready(); await complete();
  assert.equal(await page.locator('#lattice-tags input:checked').count(), 0);
  assert.equal(await clearFilters.isHidden(), true);
  assert.deepEqual(await urls(), expected);
  // Same-document passage links must reveal the article when mobile search is open.
  const workersBeforeJump = await page.evaluate(() => window.searchWorkers.length);
  await page.locator('#lattice-results').getByRole('link', { name: 'Operations', exact: true }).click();
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  assert.equal(await page.locator('article :target').isVisible(), true);
  await ready();
  await query('basil'); await complete();
  const samePagePassage = page.locator('#lattice-results').getByRole('link', { name: 'Operations', exact: true });
  await samePagePassage.focus(); await page.keyboard.press('Enter');
  assert.equal(new URL(page.url()).hash, '#training-sandbox');
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  assert.equal(await page.locator('article :target').getAttribute('id'), 'training-sandbox');
  assert.equal(await page.locator('article :target').isVisible(), true);
  assert.equal(await page.evaluate(() => window.searchWorkers.length), workersBeforeJump);
  if (process.env.LATTICE_PREVIEW_DIR) await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'passage-mobile.png') });
  await page.goBack();
  assert.equal(new URL(page.url()).hash, '#recovery-drills');
  await ready();
  await query('recovery'); await complete();
  await page.setViewportSize({ width: 1280, height: 720 });
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
  for (const mode of ['excluded-only', 'empty']) {
    indexMode = mode;
    await page.reload(); await ready();
    assert.equal(await page.locator('#lattice-filters').isHidden(), true);
    assert.equal(await page.locator('#lattice-clear-tags').isHidden(), true);
    await query('recovery'); await complete(); await status('No matching sections.');
  }
  assert.deepEqual(errors, []);
  console.log(`${browser.version()}: packaged published wiki search passed result batches/cap/focus, loading, retries, tags, DOM safety, stale replies, clearing and navigation`);
} finally {
  releaseFirst();
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
