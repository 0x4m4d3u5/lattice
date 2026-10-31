import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { createContentSearcher } from '../../examples/wasm_note/host.mjs';
import { collectEvidence, validatePublishedTarget } from '../../examples/agent_evidence/evidence.mjs';

const root = mkdtempSync(join(tmpdir(), 'lattice-wiki-starter-'));
const starter = join(root, 'my wiki');
const repository = new URL('../../', import.meta.url);
const generator = fileURLToPath(new URL('scripts/create-wiki.mjs', repository));
const cli = fileURLToPath(new URL('_build/js/debug/build/kurisu/lattice/cmd/main/main.js', repository));
const run = (script, args, cwd = root, expected = 0) => {
  const result = spawnSync(process.execPath, [script, ...args], { cwd, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(result.error);
  assert.equal(result.status, expected, result.stdout + result.stderr);
  return result;
};
const snapshot = directory => readdirSync(directory, { recursive: true, withFileTypes: true })
  .filter(entry => entry.isFile()).map(entry => {
    const path = join(entry.parentPath, entry.name);
    return [path, createHash('sha256').update(readFileSync(path)).digest('hex')];
  }).sort((a, b) => a[0].localeCompare(b[0]));

run(generator, [starter]);
assert.equal(existsSync(join(starter, 'dist')), false);
const original = snapshot(starter);
run(generator, [starter], root, 1);
assert.deepEqual(snapshot(starter), original, 'existing starter must not be overwritten');
const empty = join(root, 'existing-empty'); mkdirSync(empty);
run(generator, [empty], root, 1);
assert.deepEqual(readdirSync(empty), []);
const file = join(root, 'existing-file'); writeFileSync(file, 'keep me');
run(generator, [file], root, 1);
assert.equal(readFileSync(file, 'utf8'), 'keep me');
// Missing packaged inputs must fail before creating the requested destination.
const incomplete = join(root, 'incomplete'); mkdirSync(join(incomplete, 'scripts'), { recursive: true });
for (const name of ['create-wiki.mjs', 'wiki-package.mjs']) cpSync(new URL(`scripts/${name}`, repository), join(incomplete, 'scripts', name));
run(join(incomplete, 'scripts/create-wiki.mjs'), [join(root, 'not-created')], root, 1);
assert.equal(existsSync(join(root, 'not-created')), false);

const check = () => JSON.parse(run(cli, ['check', '--format', 'json'], starter).stdout);
assert.deepEqual(check().violations, []);
assert.equal(existsSync(join(starter, 'dist')), false);
assert.deepEqual(snapshot(starter), original, 'starter check must be read-only');
const guide = join(starter, 'content/guides/getting-started.md');
const guideSource = readFileSync(guide, 'utf8');
writeFileSync(guide, guideSource + '\n[[missing-note]]\n');
assert.ok(JSON.parse(run(cli, ['check', '--format', 'json'], starter, 1).stdout).violations.some(v => v.kind === 'broken_wikilink'));
writeFileSync(guide, guideSource.replace('description: A short tour of your connected library.\n', ''));
assert.ok(JSON.parse(run(cli, ['check', '--format', 'json'], starter, 1).stdout).violations.some(v => v.message.includes('description')));
const guideDescription = 'A "quoted" tour & <context>.';
writeFileSync(guide, guideSource.replace('A short tour of your connected library.', JSON.stringify(guideDescription)));
assert.deepEqual(check().violations, []);
run(cli, ['build'], starter);
// Follow the generated README after the initial sample wiki has been built.
const readme = readFileSync(join(starter, 'README.md'), 'utf8');
assert.ok(readme.includes('lattice new Guides --name field-journal'));
run(cli, ['new', 'Guides', '--name', 'field-journal'], starter);
const journal = join(starter, 'content/guides/field-journal.md');
assert.ok(readFileSync(journal, 'utf8').includes('title:'));
const authoredExample = readme.match(/```md\n([\s\S]*?)```/)[1];
writeFileSync(journal, authoredExample + '\n[![Garden map](/static/map.svg)](/static/map-large.svg)\n');
const mapSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="80" viewBox="0 0 160 80"><rect width="160" height="80" fill="#28734a"/><path d="M0 40H160" stroke="white" stroke-width="6"/></svg>';
writeFileSync(join(starter, 'content/static/map.svg'), mapSvg);
writeFileSync(join(starter, 'content/static/map-large.svg'), mapSvg.replace('width="160" height="80"', 'width="640" height="320"'));
writeFileSync(guide, readFileSync(guide, 'utf8') + '\n[[field-journal|Field journal]]\n');
writeFileSync(journal, readFileSync(journal, 'utf8') + '\n> [!warning] Evidence has **limits**\n> Keep the observation in context.\n>\n> > [!tip] Nested note\n> > Read the source.\n\n> [!question]- Measurement method\n> The hidden measurement explanation.\n>\n> ### Measurement evidence\n> A linked detail.\n\n> [!note]+ Open explanation\n> Visible by default.\n');
const authored = snapshot(starter);
assert.deepEqual(check().violations, []);
assert.deepEqual(snapshot(starter), authored, 'authoring check must preserve the previous build');
run(cli, ['build'], starter);
const output = join(starter, 'dist');
const index = JSON.parse(readFileSync(join(output, 'content-index.json')));
const urlFor = title => index.find(entry => entry.title === title).url;
assert.equal(index.filter(entry => entry.sections.length > 0).length, 4);
const assets = new Map();
function register(directory, prefix = '') {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const name = `${prefix}/${entry.name}`;
    if (entry.isDirectory()) register(join(directory, entry.name), name);
    else { assets.set(name, join(directory, entry.name)); if (entry.name === 'index.html') assets.set(name.slice(0, -10), join(directory, entry.name)); }
  }
}
register(output);
const mime = { '.svg': 'image/svg+xml', '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' };
const server = createServer((request, response) => {
  const file = assets.get(new URL(request.url, 'http://localhost').pathname);
  if (!file) { response.writeHead(404); response.end(); return; }
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
  // Metadata must be in the published HTML, before the search app can run.
  const noJS = await browser.newContext({ javaScriptEnabled: false });
  await noJS.route('**/*', route => new URL(route.request().url()).origin === origin ? route.continue() : route.abort());
  const published = await noJS.newPage();
  for (const [path, description, type] of [
    ['/', 'Read, connect, and publish your notes.', 'website'],
    [urlFor('Getting started'), guideDescription, 'website'],
  ]) {
    await published.goto(origin + path);
    const canonical = 'https://example.test' + path;
    assert.equal(await published.locator('head link[rel="canonical"]').count(), 1, `canonical metadata missing on ${path}`);
    assert.equal(await published.locator('head link[rel="canonical"]').getAttribute('href'), canonical);
    for (const [property, value] of Object.entries({ title: await published.title(), description, url: canonical, type })) {
      const meta = published.locator(`head meta[property="og:${property}"]`);
      assert.equal(await meta.count(), 1);
      assert.equal(await meta.getAttribute('content'), value);
    }
  }
  for (const width of [1440, 390]) {
    await published.setViewportSize({ width, height: 900 });
    await published.goto(origin + urlFor('Field journal'));
    const callout = published.locator('details.callout-question');
    assert.equal(await callout.getAttribute('open'), null);
    const summary = callout.locator('summary');
    await summary.focus();
    await summary.press('Enter');
    assert.notEqual(await callout.getAttribute('open'), null);
    assert.equal(await published.getByText('The hidden measurement explanation.', { exact: true }).isVisible(), true);
    await summary.press('Space');
    assert.equal(await callout.getAttribute('open'), null);
    assert.notEqual(await published.locator('details.callout-note').getAttribute('open'), null);
    assert.equal(await published.locator('.callout-warning > .callout-title strong').textContent(), 'limits');
    assert.equal(await published.locator('.callout-warning .callout-tip').count(), 1);
    if (process.env.LATTICE_PREVIEW_DIR) {
      mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
      await published.locator('.callout-warning').scrollIntoViewIfNeeded();
      await published.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, `callouts-${width}.png`) });
    }
    await published.goto(origin + urlFor('Field journal') + '#measurement-evidence');
    assert.equal(await published.locator('#measurement-evidence').isVisible(), true, 'native fragment navigation reveals folded evidence');
    const thumbnail = published.getByRole('img', { name: 'Garden map', exact: true });
    await thumbnail.waitFor();
    assert.equal(await thumbnail.evaluate(img => img.complete && img.naturalWidth > 0), true);
    assert.equal(await published.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    const link = published.getByRole('link', { name: 'Garden map', exact: true });
    assert.equal(await link.getAttribute('href'), '/static/map-large.svg');
    await link.focus();
    if (process.env.LATTICE_PREVIEW_DIR) {
      mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
      await published.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, `linked-thumbnail-${width}.png`) });
    }
    await Promise.all([published.waitForURL(origin + '/static/map-large.svg'), link.press('Enter')]);
    await published.goBack();
    assert.equal(new URL(published.url()).pathname, urlFor('Field journal'));
  }
  await noJS.close();
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  await context.route('**/*', route => new URL(route.request().url()).origin === origin ? route.continue() : route.abort());
  const page = await context.newPage();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  const ready = () => page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
  await page.goto(origin); await ready();
  assert.equal(await page.locator('article > header > h1').textContent(), 'Welcome to your wiki');
  assert.equal(await page.locator('#lattice-current-collection').textContent(), 'Pages');
  assert.equal(await page.locator('#lattice-page-navigation summary').filter({ hasText: /^Pages/ }).count(), 1);
  assert.equal(await page.locator('#lattice-page-navigation').getByText('_root', { exact: false }).count(), 0);
  assert.equal(await page.locator('.reading-navigation').isVisible(), false, 'a root page has no collection neighbors');
  await page.locator('article').getByRole('link', { name: 'Getting started', exact: true }).click(); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Getting started'));
  const readingOrder = page.getByRole('navigation', { name: 'Collection reading order' });
  assert.equal(await readingOrder.locator('a').count(), 2);
  assert.equal(await readingOrder.locator('[rel="prev"]').getAttribute('href'), urlFor('Field journal'));
  assert.equal(await readingOrder.locator('[rel="next"]').getAttribute('href'), urlFor('Publishing notes'));
  await page.locator('article').getByRole('link', { name: 'publishing checklist', exact: true }).click(); await ready();
  assert.equal(new URL(page.url()).hash, '#check-before-publishing');
  assert.equal(await page.locator('#check-before-publishing').count(), 1);
  await page.locator('.overview-link').click(); await ready();
  assert.equal(await page.locator('#lattice-collections a').count(), 4);
  await page.locator('#lattice-collections').getByRole('link', { name: 'Field journal', exact: true }).click(); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Field journal'));
  await page.locator('article > p').getByRole('link', { name: 'Getting started', exact: true }).click(); await ready();
  assert.equal(new URL(page.url()).pathname, urlFor('Getting started'));
  await page.getByRole('searchbox').fill('copperleaf');
  await page.getByRole('button', { name: 'Search', exact: true }).click();
  await page.locator('#lattice-results a').waitFor();
  assert.equal(await page.locator('#lattice-results a').getAttribute('href'), urlFor('Field journal') + '#first-observation');
  await page.locator('#lattice-results a').click(); await ready();
  assert.equal(await page.locator('article > header > h1').textContent(), 'Field journal');
  assert.ok((await page.locator('article').textContent()).includes('copperleaf'));
  await page.getByRole('searchbox').fill('reproducible');
  await page.getByRole('button', { name: 'Search', exact: true }).click();
  await page.locator('#lattice-results a').waitFor();
  assert.equal(await page.locator('#lattice-results a').getAttribute('href'), urlFor('Publishing notes') + '#check-before-publishing');
  await page.locator('#lattice-results a').click(); await ready();
  assert.equal(await page.locator('article > header > h1').textContent(), 'Publishing notes');
  if (process.env.LATTICE_PREVIEW_DIR) {
    mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
    await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'wiki-starter-desktop.png') });
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole('button', { name: 'Browse & search' }).click();
  await page.locator('#lattice-page-navigation').getByRole('link', { name: 'Getting started', exact: true }).click(); await ready();
  assert.equal(await page.locator('#lattice-navigation').isHidden(), true);
  assert.equal(await page.locator('article > header > h1').textContent(), 'Getting started');
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  if (process.env.LATTICE_PREVIEW_DIR) await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, 'wiki-starter-mobile.png') });
  // Complete the new-author loop with the same citation policy as the documented host.
  const search = await createContentSearcher(readFileSync(new URL('_build/wasm-gc/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.wasm', repository)));
  const validation = await browser.newContext({ javaScriptEnabled: false });
  const evidence = query => collectEvidence({ indexJson: readFileSync(join(output, 'content-index.json'), 'utf8'), query, search, origin,
    validateTarget: (url, fragment) => validatePublishedTarget(validation, url, fragment) });
  const first = await evidence('copperleaf');
  assert.equal(first.status, 'ready');
  assert.ok(first.candidates[0].passage.includes('copperleaf'));
  assert.equal(first.citation.url, origin + urlFor('Field journal') + '#first-observation');
  const beforeEdit = readFileSync(journal, 'utf8');
  writeFileSync(journal, beforeEdit.replace('copperleaf', 'silverfern'));
  const beforeCheck = snapshot(starter);
  assert.deepEqual(check().violations, []);
  assert.deepEqual(snapshot(starter), beforeCheck, 'check after editing must not write output');
  run(cli, ['build', '--strict-wikilinks'], starter);
  assert.equal((await evidence('copperleaf')).status, 'no_results');
  const updated = await evidence('silverfern');
  assert.equal(updated.status, 'ready');
  assert.equal(updated.citation.url, first.citation.url);
  assert.ok(updated.candidates[0].passage.includes('silverfern'));
  await page.goto(updated.citation.url); await ready();
  assert.ok((await page.locator('article').textContent()).includes('silverfern'));
  assert.equal(new URL(page.url()).hash, '#first-observation');
  await validation.close();
  assert.deepEqual(errors, []);
  console.log(`${browser.version()}: fresh wiki starter, README authoring/rebuild, refusal/preflight, read-only check, typed schema, wikilinks, no-JS publishing metadata, desktop/mobile navigation and real WASM search passed (${root})`);
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
