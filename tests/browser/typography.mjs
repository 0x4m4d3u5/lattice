import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, cpSync, readFileSync, writeFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { chromium } from 'playwright';

const repository = fileURLToPath(new URL('../../', import.meta.url));
const root = mkdtempSync(join(tmpdir(), 'lattice-reading-stress-'));
const content = join(root, 'content'), templates = join(root, 'templates'), output = join(root, 'dist');
mkdirSync(content); mkdirSync(templates); mkdirSync(join(content, 'static')); mkdirSync(join(content, 'data'));
cpSync(new URL('./fixtures/reading-stress.md', import.meta.url), join(content, 'fieldnotes.md'));
for (const name of ['page.html', 'wiki-navigation.html']) cpSync(join(repository, 'examples/wiki_search', name), join(templates, name));
writeFileSync(join(templates, '404.html'), '{{content}}');
writeFileSync(join(root, 'site.cfg'), `title = Reading stress\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
function run(script, args) {
  const result = spawnSync(process.execPath, [join(repository, script), ...args], { cwd: root, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
}
run('scripts/package-search.mjs', [join(content, 'static/search')]);
run('_build/js/debug/build/kurisu/lattice/cmd/main/main.js', ['build', content, '-c', join(root, 'site.cfg')]);
const index = JSON.parse(readFileSync(join(output, 'content-index.json')));
const url = index.find(entry => entry.title === 'Code fieldnotes').url;
const mime = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' };
const server = createServer((request, response) => {
  try {
    let file = join(output, new URL(request.url, 'http://localhost').pathname);
    if (statSync(file).isDirectory()) file = join(file, 'index.html');
    response.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream' }); response.end(readFileSync(file));
  } catch { response.writeHead(404); response.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser;
try {
  const channel = process.env.LATTICE_BROWSER_CHANNEL ?? 'chromium';
  browser = await chromium.launch({ chromiumSandbox: true, ...(channel === 'chrome' ? { channel } : {}) });
  for (const javaScriptEnabled of [true, false]) {
    const context = await browser.newContext({ javaScriptEnabled });
    await context.route('**/*', route => new URL(route.request().url()).origin === origin ? route.continue() : route.abort());
    const page = await context.newPage();
    for (const [width, size] of [[320, 32], [390, 32], [320, 16], [390, 16], [1440, 16]]) {
      await page.setViewportSize({ width, height: 900 }); await page.goto(origin + url);
      if (javaScriptEnabled) await page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
      await page.evaluate(size => document.documentElement.style.fontSize = `${size}px`, size);
      if (process.env.LATTICE_PREVIEW_DIR) {
        mkdirSync(process.env.LATTICE_PREVIEW_DIR, { recursive: true });
        await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, `reading-stress-${width}-${size}-${javaScriptEnabled ? 'js' : 'plain'}.png`), fullPage: false });
      }
      if (process.env.LATTICE_PREVIEW_DIR && width === 320 && size === 32 && javaScriptEnabled) {
        for (const [name, selector] of [['callout', 'article .callout'], ['code', 'article pre']]) {
          await page.locator(selector).scrollIntoViewIfNeeded();
          await page.screenshot({ path: join(process.env.LATTICE_PREVIEW_DIR, `reading-stress-${name}.png`) });
        }
      }
      const layout = await page.locator('article').evaluate(article => {
        const lines = element => {
          const range = document.createRange(); range.selectNodeContents(element);
          return new Set([...range.getClientRects()].map(rect => Math.round(rect.top))).size;
        };
        const title = article.querySelector('h1');
        const range = document.createRange();
        const wordStart = title.firstChild.textContent.indexOf('fieldnotes');
        range.setStart(title.firstChild, wordStart); range.setEnd(title.firstChild, wordStart + 'fieldnotes'.length);
        const pre = article.querySelector('pre');
        return {
          titleWordLines: new Set([...range.getClientRects()].map(rect => Math.round(rect.top))).size,
          wordLines: ['prose-word', 'callout-word', 'list-word'].map(id => lines(document.getElementById(id))),
          titleSize: parseFloat(getComputedStyle(title).fontSize),
          bodySize: parseFloat(getComputedStyle(article).fontSize),
          overflow: document.documentElement.scrollWidth > innerWidth,
          codeScrollable: pre.scrollWidth > pre.clientWidth && getComputedStyle(pre).overflowX === 'auto',
          codeText: pre.textContent,
        };
      });
      assert.equal(layout.titleWordLines, 1, 'fieldnotes fits without an emergency split');
      assert.deepEqual(layout.wordLines, [1, 1, 1], 'ordinary words fit in prose, callout and nested list');
      assert.ok(layout.titleSize >= size * 2.125 && layout.bodySize >= size * 1.125, 'preserve enlarged text');
      assert.equal(layout.overflow, false, 'long links and tokens must not overflow the page');
      assert.equal(layout.codeScrollable, true, 'long code stays horizontally scrollable');
      assert.ok(layout.codeText.includes('    indented continuation'), 'preserve code whitespace');
      const link = page.getByRole('link', { name: 'the next section', exact: true });
      await link.focus();
      assert.notEqual(await link.evaluate(element => getComputedStyle(element).outlineStyle), 'none');
      await link.press('Enter');
      assert.equal(new URL(page.url()).hash, '#follow-the-evidence');
      assert.ok((await page.locator('#follow-the-evidence').boundingBox()).y >= (await page.locator('.masthead').boundingBox()).height);
    }
    await context.close();
  }
  console.log(`${browser.version()}: mixed reading typography, enlarged text, native anchors, long-token containment, code scrolling and no-JS passed`);
} finally { if (browser) await browser.close(); await new Promise(resolve => server.close(resolve)); }
