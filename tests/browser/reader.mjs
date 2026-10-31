import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, cpSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { checkReaderStyle } from './reader-style.mjs';

const repository = new URL('../../', import.meta.url);
const root = mkdtempSync(join(tmpdir(), 'lattice-reader-ui-'));
const content = join(root, 'content');
const output = join(root, 'dist');
const templates = join(root, 'templates');
cpSync(new URL('./fixtures/wiki', import.meta.url), content, { recursive: true });
mkdirSync(join(content, 'static'), { recursive: true });
writeFileSync(join(content, 'static/diagram.png'), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jS1sAAAAASUVORK5CYII=', 'base64'));
const sharingNote = join(content, 'guides/publishing-a-note.md');
const entryNote = join(content, 'guides/getting-started.md');
writeFileSync(entryNote, readFileSync(entryNote, 'utf8').replace('[[publishing-a-note]]', '[[Contribution Guide|publishing-a-note]]'));
writeFileSync(sharingNote, readFileSync(sharingNote, 'utf8').replace('toc: true', 'toc: false\naliases: ["Contribution Guide"]') + `
![[diagram.png]]

## Repeated section

First passage.

## Repeated section

Second passage.

<h3 id="☕ 50%:a/b">A custom section with punctuation</h3>
<h3 id="already-linked"><a href="#already-linked">Existing section link</a></h3>
<h3 id="discount-50%"><a href="#discount-50%">Existing percent section link</a></h3>
<h3 id="lattice-query">Ambiguous with the search input</h3>
<h3 id="linked-label"><a href="/wiki/static/search/">An authored link</a> stays intact</h3>
<h3 id="">No target</h3>
<h3 id="space target">Shadowed encoded ID</h3>
<div id="space%20target">Another raw fragment target</div>
<h3 id="named space">Shadowed encoded name</h3>
<a name="named%20space">Legacy named target</a>
`);
const copySource = 'let greeting = "café <world> & friends"\n\tprintln(greeting)\n';
writeFileSync(sharingNote, readFileSync(sharingNote, 'utf8') + '\n## Copy an example\n\n```moonbit\n' + copySource + '```\n\n```text\n  keep indentation\n\nlast line\n```\n');
mkdirSync(templates);
mkdirSync(join(content, 'static'), { recursive: true });
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
writeFileSync(config, `wikilink_aliases = true\ntitle = Fieldnotes\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
run('_build/js/debug/build/kurisu/lattice/cmd/main/main.js', ['build', content, '-c', config, '--collections', collections]);
const index = JSON.parse(readFileSync(join(output, 'content-index.json')));
const urlFor = title => index.find(entry => entry.title === title).url;
const mime = { '.png': 'image/png', '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' };
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
  // Allow the first breakpoint notification to arrive after the user opens the menu.
  await page.addInitScript(() => {
    const matchMedia = window.matchMedia.bind(window);
    window.pendingLayoutChanges = [];
    window.matchMedia = query => {
      const media = matchMedia(query);
      const add = media.addEventListener.bind(media);
      media.addEventListener = (type, listener, options) => add(type, event => {
        const deliver = () => listener.call(media, event);
        if (type === 'change' && window.holdLayoutChanges) window.pendingLayoutChanges.push(deliver);
        else deliver();
      }, options);
      return media;
    };
  });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const ready = () => page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  const save = async name => {
    if (!process.env.LATTICE_PREVIEW_DIR) return;
    mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
    await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, name), fullPage: name.includes('landing') });
  };
  const checkForcedColors = async name => {
    await page.emulateMedia({ forcedColors: 'active' });
    const current = page.locator('#lattice-navigation [aria-current=page]');
    assert.equal(await current.count(), 1);
    assert.equal(await current.evaluate(link => {
      const style = getComputedStyle(link);
      return style.borderInlineStartStyle === 'solid' && parseFloat(style.borderInlineStartWidth) > 0
        && style.borderInlineStartColor !== style.backgroundColor;
    }), true, 'Current page needs a visible marker when forced colors removes backgrounds and shadows');
    assert.equal(await page.locator('#lattice-page-navigation a:not([aria-current])').evaluateAll(links =>
      links.every(link => parseFloat(getComputedStyle(link).borderInlineStartWidth) === 0)), true);
    await current.focus();
    await page.keyboard.press('Tab'); await page.keyboard.press('Shift+Tab');
    assert.equal(await current.evaluate(link => {
      const style = getComputedStyle(link);
      return document.activeElement === link && style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0;
    }), true, 'Keyboard focus must remain distinct from the current-page marker');
    await save(name);
    await current.evaluate(link => link.blur());
    await page.emulateMedia({ forcedColors: 'none' });
  };
  const checkPrint = async name => {
    const menuState = await page.locator('#lattice-navigation-toggle').getAttribute('aria-expanded');
    await page.emulateMedia({ media: 'print' });
    assert.equal(await page.locator('article').isVisible(), true, 'Printing must include the note even with mobile navigation open');
    assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
    assert.equal(await page.locator('.masthead').isHidden(), true);
    assert.equal(await page.locator('main').evaluate(main => getComputedStyle(main).marginLeft), '0px');
    await save(name);
    if (process.env.LATTICE_PREVIEW_DIR) await page.pdf({ path: join(process.env.LATTICE_PREVIEW_DIR, name.replace('.png', '.pdf')), format: 'A4' });
    await page.emulateMedia({ media: 'screen' });
    assert.equal(await page.locator('#lattice-navigation-toggle').getAttribute('aria-expanded'), menuState);
    if (await page.locator('#lattice-navigation-toggle').isVisible()) {
      assert.equal(await page.locator('#lattice-navigation').isVisible(), menuState === 'true');
      assert.equal(await page.locator('article').isVisible(), menuState !== 'true');
    }
  };
  // Clipboard contents must be exactly the published code, never control labels.
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin });
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto(`${origin}${urlFor('Publishing a note')}`); await ready();
    const attachment = page.locator('article img[alt="diagram.png"]');
    await attachment.evaluate(image => image.decode());
    assert.equal(await attachment.evaluate(image => image.naturalWidth), 1);
    assert.equal(await attachment.getAttribute('src'), '/static/diagram.png');
    const copy = page.locator('article').getByRole('button', { name: 'Copy code', exact: true }).first();
    assert.equal(await copy.count(), 1, 'Readers need a copy control for code examples');
    const code = page.locator('article pre > code').first();
    const publishedText = await code.textContent();
    assert.equal(publishedText, copySource.slice(0, -1));
    assert.ok(await code.locator('span').count() > 0, 'Exercise syntax-highlighted code');
    await copy.focus(); await page.keyboard.press('Tab'); await page.keyboard.press('Shift+Tab');
    assert.equal(await copy.evaluate(button => document.activeElement === button && getComputedStyle(button).outlineStyle !== 'none'), true);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => [...document.querySelectorAll('article [role="status"]')].some(node => node.textContent === 'Code copied.'));
    assert.equal(await page.evaluate(() => navigator.clipboard.readText()), publishedText);
    assert.equal(await code.textContent(), publishedText);
    assert.equal(await copy.evaluate(button => document.activeElement === button), true);
    await copy.scrollIntoViewIfNeeded(); await save(`copy-code-${width}.png`);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.emulateMedia({ forcedColors: 'active' });
    assert.equal(await copy.evaluate(button => getComputedStyle(button).outlineStyle !== 'none'), true);
    await page.emulateMedia({ forcedColors: 'none', media: 'print' });
    assert.equal(await copy.isHidden(), true);
    assert.equal(await code.isVisible(), true);
    await page.emulateMedia({ media: 'screen' });
  }
  const copy = page.locator('article').getByRole('button', { name: 'Copy code', exact: true }).first();
  await page.evaluate(() => {
    window.copyCalls = [];
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      writeText(text) { window.copyCalls.push(text); return new Promise((resolve, reject) => { window.finishCopy = { resolve, reject }; }); },
    } });
  });
  await copy.focus(); await page.keyboard.press('Enter'); await page.keyboard.press('Enter');
  assert.equal(await page.evaluate(() => window.copyCalls.length), 1, 'Pending copy must ignore duplicate activation');
  assert.equal(await copy.evaluate(button => document.activeElement === button), true);
  await page.evaluate(() => window.finishCopy.reject(new Error('Clipboard denied')));
  await page.waitForFunction(() => [...document.querySelectorAll('article [role="status"]')].some(node => /select.*copy.*manually/i.test(node.textContent)));
  await page.keyboard.press('Enter');
  assert.equal(await page.evaluate(() => window.copyCalls.length), 2, 'A denied copy can be retried');
  await page.evaluate(() => window.finishCopy.resolve());
  await page.waitForFunction(() => [...document.querySelectorAll('article [role="status"]')].some(node => node.textContent === 'Code copied.'));
  const unsupported = await context.newPage();
  await unsupported.addInitScript(() => Object.defineProperty(navigator, 'clipboard', { value: undefined }));
  await unsupported.goto(`${origin}${urlFor('Publishing a note')}`);
  await unsupported.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  assert.equal(await unsupported.locator('article').getByRole('button', { name: 'Copy code', exact: true }).count(), 0);
  assert.equal(await unsupported.locator('article pre > code').first().textContent(), copySource.slice(0, -1));
  await unsupported.close();
  // Sharing a section should not require a TOC, a guessed slug or clipboard access.
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto(`${origin}${urlFor('Publishing a note')}`); await ready();
    assert.equal(await page.locator('article .contents').count(), 0);
    const section = page.getByRole('link', { name: 'Link to section: Start with the question', exact: true });
    assert.equal(await section.count(), 1, 'A note without TOC needs a visible section permalink');
    const expectedHash = '#' + encodeURIComponent(await section.evaluate(link => link.parentElement.id));
    assert.equal(await section.getAttribute('href'), expectedHash);
    await section.focus(); await page.keyboard.press('Tab'); await page.keyboard.press('Shift+Tab');
    assert.equal(await section.evaluate(link => document.activeElement === link && getComputedStyle(link).outlineStyle !== 'none'), true);
    const box = await section.boundingBox();
    assert.ok(box.width >= 24 && box.height >= 24, 'Permalink needs a usable touch target');
    await Promise.all([page.waitForURL(url => url.hash === expectedHash), page.keyboard.press('Enter')]);
    assert.equal(new URL(page.url()).hash, expectedHash);
    await page.goBack();
    assert.equal(new URL(page.url()).hash, '');
    const repeats = page.getByRole('link', { name: 'Link to section: Repeated section', exact: true });
    assert.equal(await repeats.count(), 2);
    const repeatTargets = await repeats.evaluateAll(links => links.map(link => link.getAttribute('href')));
    assert.equal(new Set(repeatTargets).size, 2, 'Use separately emitted IDs for repeated heading text');
    const custom = page.getByRole('link', { name: 'Link to section: A custom section with punctuation', exact: true });
    assert.equal(await custom.getAttribute('href'), '#' + encodeURIComponent('☕ 50%:a/b'));
    await custom.click();
    assert.equal(decodeURIComponent(new URL(page.url()).hash.slice(1)), '☕ 50%:a/b');
    assert.equal(await page.locator('#already-linked a').count(), 1, 'Do not duplicate an authored self-link');
    assert.equal(await page.locator('[id="discount-50%"] a').count(), 1, 'A literal percent in an authored self-link is valid');
    assert.equal(await page.locator('h3[id="lattice-query"] a').count(), 0, 'An ID duplicated outside the article is ambiguous');
    assert.equal(await page.locator('#linked-label a').count(), 2);
    assert.equal(await page.locator('#linked-label a a').count(), 0, 'Do not nest anchors');
    assert.equal(await page.locator('h3[id=""] a').count(), 0);
    assert.equal(await page.locator('h3[id="space target"] a').count(), 0, 'An encoded fragment must not resolve to another literal ID');
    assert.equal(await page.locator('h3[id="named space"] a').count(), 0, 'An encoded fragment must not resolve to a legacy named anchor');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await custom.focus();
    await save(`section-links-${width}.png`);
    await page.emulateMedia({ forcedColors: 'active' });
    assert.equal(await custom.evaluate(link => getComputedStyle(link).color !== getComputedStyle(document.body).backgroundColor), true);
    await page.emulateMedia({ forcedColors: 'none', media: 'print' });
    assert.equal(await custom.isHidden(), true);
    await page.emulateMedia({ media: 'screen' });
    if (width === 1440) {
      const [opened] = await Promise.all([context.waitForEvent('page'), section.click({ button: 'middle' })]);
      await opened.waitForLoadState();
      assert.equal(new URL(opened.url()).hash, expectedHash);
      await opened.close();
    }
  }
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto(`${origin}/wiki/static/search/`); await ready();
  assert.equal(await page.getByRole('searchbox').inputValue(), '');
  assert.equal(await page.locator('#lattice-collections .collection').count(), 3);
  assert.equal(await page.locator('#lattice-page-navigation a').count(), 6);
  assert.equal(await page.locator('#lattice-collections a').count(), 6);
  await save('landing-desktop.png');
  await page.locator('.overview-link').focus();
  await page.keyboard.press('Tab'); await page.keyboard.press('Shift+Tab');
  await checkReaderStyle(page);
  await checkForcedColors('landing-forced-colors.png');
  const start = page.locator('#lattice-collections').getByRole('link', { name: 'Getting started', exact: true });
  await start.focus(); await page.keyboard.press('Enter'); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Getting started'));
  assert.equal(await page.locator('#lattice-page-navigation [aria-current=page]').textContent(), 'Getting started');
  assert.equal(await page.locator('#lattice-current-collection').textContent(), 'Guides');
  const onward = page.getByRole('navigation', { name: 'Collection reading order' });
  assert.equal(await onward.locator('a').count(), 1);
  assert.equal(new URL(await onward.locator('a').getAttribute('href'), page.url()).pathname, urlFor('Publishing a note'));
  await onward.locator('a').focus(); await page.keyboard.press('Enter'); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Publishing a note'));
  await page.getByRole('navigation', { name: 'Collection reading order' }).locator('a').click(); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Getting started'));
  await onward.scrollIntoViewIfNeeded();
  await save('reading-order-desktop.png');
  await page.evaluate(() => scrollTo(0, 0));
  assert.equal(await page.locator('iframe').count(), 0);
  assert.equal(await page.evaluate(() => document.getElementById('navigation')?.tagName), 'H2');
  await save('reader-desktop.png');
  await checkReaderStyle(page);
  await checkForcedColors('reader-forced-colors.png');
  await checkPrint('reader-print-desktop.png');
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
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.locator('.overview-link').focus();
  await page.evaluate(() => { window.holdLayoutChanges = true; });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForFunction(() => document.activeElement === document.querySelector('#lattice-navigation-toggle'), null, { timeout: 2000 });
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  assert.equal(await page.getByRole('search', { name: 'Wiki search', exact: true }).count(), 0);
  const toggle = page.getByRole('button', { name: 'Browse & search' });
  await toggle.focus(); await page.keyboard.press('Enter');
  assert.equal(await toggle.getAttribute('aria-expanded'), 'true');
  assert.equal(await page.locator('#lattice-navigation').isVisible(), true);
  assert.equal(await page.getByRole('search', { name: 'Wiki search', exact: true }).getByRole('searchbox', { name: 'Search notes', exact: true }).count(), 1);
  await page.waitForFunction(() => window.pendingLayoutChanges.length > 0);
  await page.evaluate(() => {
    window.holdLayoutChanges = false;
    for (const deliver of window.pendingLayoutChanges.splice(0)) deliver();
  });
  assert.equal(await toggle.getAttribute('aria-expanded'), 'true');
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
  await checkReaderStyle(page);
  await checkPrint('reader-print-mobile-closed.png');
  await toggle.click(); await save('navigation-mobile.png');
  await checkReaderStyle(page);
  await checkForcedColors('navigation-mobile-forced-colors.png');
  await checkPrint('reader-print-mobile-open.png');
  await page.locator('.overview-link').click(); await ready();
  await save('landing-mobile.png');
  await checkReaderStyle(page);
  assert.equal(await page.locator('#lattice-collections').isVisible(), true);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  // Narrow CSS viewport also exercises the reflow used by browser zoom. Keep
  // article, controls and real search results readable on both sides of 800px.
  for (const width of [320, 800, 801]) {
    await page.setViewportSize({ width, height: 844 });
    await page.goto(`${origin}${urlFor('Getting started')}`); await ready();
    await checkReaderStyle(page);
    if (width <= 800) await toggle.click();
    await page.getByRole('searchbox').fill('publishing');
    await page.getByRole('button', { name: 'Search', exact: true }).click();
    await page.locator('#lattice-results a').first().waitFor();
    await checkReaderStyle(page);
    if (width === 320) await save('navigation-narrow-search.png');
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${origin}/wiki/static/search/`); await ready();
  // Directory and published reading survive failure of the search runtime.
  failWasm = true;
  await page.reload();
  await page.waitForFunction(() => document.querySelector('#lattice-status').textContent.startsWith('Search is unavailable'));
  assert.equal(await page.locator('#lattice-collections a').count(), 6);
  await page.locator('#lattice-collections').getByRole('link', { name: 'Getting started', exact: true }).click();
  await page.locator('article').waitFor();
  await page.waitForFunction(() => document.querySelector('#lattice-status').textContent.startsWith('Search is unavailable'));
  assert.ok((await page.locator('article').textContent()).includes('Find your way around'));
  assert.equal(await page.getByRole('link', { name: 'Link to section: Find your way around', exact: true }).count(), 1, 'Section links must survive search runtime failure');
  await page.goto(`${origin}${urlFor('Publishing a note')}`);
  await page.waitForFunction(() => document.querySelector('#lattice-status').textContent.startsWith('Search is unavailable'));
  assert.equal(await page.locator('article').getByRole('button', { name: 'Copy code', exact: true }).count(), 2, 'Copy controls must survive search failure');
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
  assert.equal(await plain.locator('.section-permalink').count(), 0, 'No-JS reading keeps the original published content');
  assert.ok((await plain.locator('article').textContent()).includes('Find your way around'));
  await plain.locator('article').getByRole('link', { name: 'publishing-a-note', exact: true }).click();
  assert.equal(new URL(plain.url()).pathname, urlFor('Publishing a note'));
  await plain.locator('article img[alt="diagram.png"]').evaluate(image => image.decode());
  assert.equal(await plain.locator('article img[alt="diagram.png"]').evaluate(image => image.naturalWidth), 1);
  assert.equal(await plain.locator('article').getByRole('button', { name: 'Copy code', exact: true }).count(), 0);
  assert.equal(await plain.locator('article pre > code').first().textContent(), copySource.slice(0, -1));
  await plain.setViewportSize({ width: 320, height: 800 });
  const previous = plain.getByRole('navigation', { name: 'Collection reading order' }).locator('a');
  assert.ok((await previous.textContent()).includes('Getting started'));
  await previous.click();
  assert.equal(new URL(plain.url()).pathname, urlFor('Getting started'));
  assert.equal(await plain.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  if (process.env.LATTICE_PREVIEW_DIR) {
    await plain.getByRole('navigation', { name: 'Collection reading order' }).scrollIntoViewIfNeeded();
    await plain.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'reading-order-mobile-no-js.png') });
  }
  await noJS.close();
  assert.deepEqual(errors, []);
  console.log(`${browser.version()}: reader code-copy success/denial/focus, landing, collections, wiki/fragment links, history, mobile, keyboard, contrast/type/reflow, search-runtime failure and no-JS reading passed (${root})`);
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
