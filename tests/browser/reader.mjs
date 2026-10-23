import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, cpSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { chromium } from 'playwright';

const repository = new URL('../../', import.meta.url);
const root = mkdtempSync(join(tmpdir(), 'lattice-reader-ui-'));
const content = join(root, 'content');
const output = join(root, 'dist');
const templates = join(root, 'templates');
cpSync(new URL('./fixtures/wiki', import.meta.url), content, { recursive: true });
mkdirSync(templates);
mkdirSync(join(content, 'static'));
mkdirSync(join(content, 'data'));
const run = (path, args) => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL(path, repository)), ...args], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
};
run('scripts/package-search.mjs', [join(content, 'static/search')]);
for (const name of ['page.html', 'wiki-navigation.html']) {
  writeFileSync(join(templates, name), readFileSync(new URL(`examples/wiki_search/${name}`, repository), 'utf8')
    .replaceAll('/static/search/', '/wiki/static/search/').replace('/content-index.json', '/wiki/content-index.json'));
}
writeFileSync(join(templates, '404.html'), '{{content}}');
const collections = join(root, 'collections.cfg');
writeFileSync(collections, ['Guides', 'Systems', 'Practices'].map(name => `[${name}]\ndir = ${join(content, name.toLowerCase())}\nschema = title:String,description:String,tags:Optional[Array[String]]\n`).join('\n'));
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Fieldnotes\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
run('_build/js/debug/build/kurisu/lattice/cmd/main/main.js', ['build', content, '-c', config, '--collections', collections]);
const index = JSON.parse(readFileSync(join(output, 'content-index.json')));
const urlFor = title => index.find(entry => entry.title === title).url;
const mime = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' };
const assets = new Map();
function register(directory, prefix = '') {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const name = `${prefix}/${entry.name}`;
    if (entry.isDirectory()) register(join(directory, entry.name), name);
    else { assets.set(name, join(directory, entry.name)); if (entry.name === 'index.html') assets.set(name.slice(0, -10), join(directory, entry.name)); }
  }
}
register(output);
let failWasm = false;
const server = createServer((request, response) => {
  const pathname = new URL(request.url, 'http://localhost').pathname.replace(/^\/wiki(?=\/)/, '');
  const file = assets.get(pathname);
  if (!file || (failWasm && pathname.endsWith('.wasm'))) { response.writeHead(404); response.end(); return; }
  response.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream' });
  response.end(readFileSync(file));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser;
try {
  const channel = process.env.LATTICE_BROWSER_CHANNEL ?? 'chromium';
  assert.ok(['chrome', 'chromium'].includes(channel));
  browser = await chromium.launch({ headless: true, chromiumSandbox: true, ...(channel === 'chrome' ? { channel } : {}) });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  await context.route('**/*', route => new URL(route.request().url()).origin === origin ? route.continue() : route.abort());
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const ready = () => page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  const save = async name => {
    if (!process.env.LATTICE_PREVIEW_DIR) return;
    mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
    await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, name), fullPage: name.includes('landing') });
  };
  await page.goto(`${origin}/wiki/static/search/`); await ready();
  assert.equal(await page.getByRole('searchbox').inputValue(), '');
  assert.equal(await page.locator('#lattice-collections .collection').count(), 3);
  assert.equal(await page.locator('#lattice-page-navigation a').count(), 6);
  assert.equal(await page.locator('#lattice-collections a').count(), 6);
  await save('landing-desktop.png');
  const start = page.locator('#lattice-collections').getByRole('link', { name: 'Getting started', exact: true });
  await start.focus(); await page.keyboard.press('Enter'); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Getting started'));
  assert.equal(await page.locator('#lattice-page-navigation [aria-current=page]').textContent(), 'Getting started');
  assert.equal(await page.locator('#lattice-current-collection').textContent(), 'Guides');
  assert.equal(await page.locator('iframe').count(), 0);
  assert.equal(await page.evaluate(() => document.getElementById('navigation')?.tagName), 'H2');
  await save('reader-desktop.png');
  // A real wikilink, then a heading link, preserve the shared shell and native URL.
  await page.locator('article').getByRole('link', { name: 'publishing-a-note', exact: true }).click(); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Publishing a note'));
  await page.locator('article').getByRole('link', { name: 'the publishing flow', exact: true }).click(); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('The system map'));
  assert.equal(new URL(page.url()).hash, '#source-to-page');
  assert.ok((await page.locator('#source-to-page').boundingBox()).y >= (await page.locator('.masthead').boundingBox()).height);
  assert.equal(await page.locator('#lattice-page-navigation [aria-current=page]').textContent(), 'The system map');
  assert.equal(await page.locator('#lattice-current-collection').textContent(), 'Systems');
  await page.goBack(); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Publishing a note'));
  await page.goBack(); await ready();
  // Contents disclosure and genuine generated backlinks remain keyboard usable.
  const summary = page.locator('article .contents summary');
  await summary.focus(); await page.keyboard.press('Enter');
  const target = page.locator('article .contents').getByRole('link', { name: 'Follow the connections', exact: true });
  await target.focus(); await page.keyboard.press('Enter');
  assert.equal(new URL(page.url()).hash, '#follow-the-connections');
  assert.ok(await page.locator('article .backlinks a').count() > 0);
  // Group disclosure state survives ordinary navigation; active group is visible.
  const systems = page.locator('#lattice-page-navigation details').filter({ has: page.getByText('Systems · 2', { exact: true }) });
  await systems.locator('summary').click();
  await page.locator('article').getByRole('link', { name: 'publishing-a-note', exact: true }).click(); await ready();
  assert.equal(await systems.evaluate(element => element.open), false);
  // Crossing the responsive breakpoint must not strand keyboard focus in hidden UI.
  await page.locator('.overview-link').focus();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForFunction(() => document.activeElement === document.querySelector('#lattice-navigation-toggle'), null, { timeout: 2000 });
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  const toggle = page.getByRole('button', { name: 'Browse & search' });
  await toggle.focus(); await page.keyboard.press('Enter');
  assert.equal(await toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(await page.locator('#lattice-navigation').isVisible(), true);
  await page.keyboard.press('Escape');
  assert.equal(await toggle.evaluate(element => element === document.activeElement), true);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.waitForFunction(() => document.activeElement === document.querySelector('.overview-link'));
  assert.equal(await toggle.isHidden(), true);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForFunction(() => document.activeElement === document.querySelector('#lattice-navigation-toggle'), null, { timeout: 2000 });
  await toggle.click();
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.waitForFunction(() => document.querySelector('#lattice-navigation-toggle').getAttribute('aria-expanded') === 'false');
  assert.equal(await page.locator('main').isVisible(), true);
  assert.equal(await page.locator('.overview-link').evaluate(element => element === document.activeElement), true);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForFunction(() => document.activeElement === document.querySelector('#lattice-navigation-toggle'), null, { timeout: 2000 });
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  assert.equal(await page.locator('main').isVisible(), true);
  await page.locator('main').focus();
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 844 });
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(resolve)));
    assert.equal(await page.locator('main').evaluate(element => element === document.activeElement), true);
  }
  await toggle.click();
  await page.getByRole('link', { name: 'Skip to content' }).focus(); await page.keyboard.press('Enter');
  assert.equal(await page.locator('main').evaluate(element => element === document.activeElement), true);
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  await toggle.click();
  await page.locator('#lattice-page-navigation').getByRole('link', { name: 'Getting started', exact: true }).click(); await ready();
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  // Dismissing mobile navigation returns to the passage being read.
  await page.setViewportSize({ width: 390, height: 500 });
  await page.locator('#navigation').scrollIntoViewIfNeeded();
  const readingPosition = await page.evaluate(() => scrollY);
  assert.ok(readingPosition > 100);
  await toggle.click();
  await page.keyboard.press('Escape');
  assert.equal(await page.evaluate(() => scrollY), readingPosition);
  assert.equal(await toggle.evaluate(element => element === document.activeElement), true);
  await toggle.click();
  await page.locator('#lattice-page-navigation a').last().scrollIntoViewIfNeeded();
  await toggle.click();
  assert.equal(await page.evaluate(() => scrollY), readingPosition);
  await toggle.click();
  await page.getByRole('link', { name: 'Skip to content' }).focus(); await page.keyboard.press('Enter');
  assert.equal(await page.locator('main').evaluate(element => element === document.activeElement), true);
  assert.ok(await page.evaluate(() => scrollY) < readingPosition);
  await page.setViewportSize({ width: 390, height: 844 });
  await save('reader-mobile.png');
  await toggle.click(); await save('navigation-mobile.png');
  await page.locator('.overview-link').click(); await ready();
  await save('landing-mobile.png');
  assert.equal(await page.locator('#lattice-collections').isVisible(), true);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  // Directory and published reading survive failure of the search runtime.
  failWasm = true;
  await page.reload();
  await page.waitForFunction(() => document.querySelector('#lattice-status').textContent.startsWith('Search is unavailable'));
  assert.equal(await page.locator('#lattice-collections a').count(), 6);
  await page.locator('#lattice-collections').getByRole('link', { name: 'Getting started', exact: true }).click();
  await page.locator('article').waitFor();
  assert.ok((await page.locator('article').textContent()).includes('Find your way around'));
  failWasm = false;
  // Optional browser storage and JavaScript are not prerequisites for page reading.
  const restricted = await context.newPage();
  await restricted.addInitScript(() => Object.defineProperty(window, 'sessionStorage', { get() { throw new Error('Storage unavailable'); } }));
  await restricted.goto(`${origin}/wiki/static/search/`);
  await restricted.locator('#lattice-collections a').first().waitFor();
  await restricted.close();
  const noJS = await browser.newContext({ javaScriptEnabled: false });
  const plain = await noJS.newPage();
  await plain.goto(`${origin}${urlFor('Getting started')}`);
  assert.ok((await plain.locator('article').textContent()).includes('Find your way around'));
  await plain.locator('article').getByRole('link', { name: 'publishing-a-note', exact: true }).click();
  assert.equal(new URL(plain.url()).pathname, urlFor('Publishing a note'));
  await noJS.close();
  assert.deepEqual(errors, []);
  console.log(`${browser.version()}: reader landing, collections, wiki/fragment links, history, mobile, keyboard, search-runtime failure and no-JS reading passed (${root})`);
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
