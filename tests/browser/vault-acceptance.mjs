import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join, extname } from 'node:path';
import { createServer } from 'node:http';
import { chromium } from 'playwright';
import { vaultAcceptance } from '../../scripts/check-vault-acceptance.mjs';

const { output, evidenceUrl, overviewUrl } = vaultAcceptance();
const files = new Map();
function collect(dir, prefix = '') {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const url = `${prefix}/${e.name}`;
    if (e.isDirectory()) collect(join(dir, e.name), url);
    else { files.set(url, join(dir, e.name)); if (e.name === 'index.html') files.set(url.slice(0, -10), join(dir, e.name)); }
  }
}
collect(output);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png' };
const server = createServer((req, res) => {
  const path = files.get(new URL(req.url, 'http://localhost').pathname);
  if (!path) { res.writeHead(404); res.end(); return; }
  res.setHeader('Content-Type', types[extname(path)] ?? 'application/octet-stream'); res.end(readFileSync(path));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ chromiumSandbox: true, ...(process.env.LATTICE_BROWSER_CHANNEL ? { channel: process.env.LATTICE_BROWSER_CHANNEL } : {}) });
try {
  for (const javaScriptEnabled of [true, false]) {
    const context = await browser.newContext({ javaScriptEnabled, viewport: { width: javaScriptEnabled ? 1440 : 390, height: 900 } });
    const page = await context.newPage();
    await page.goto(origin + overviewUrl);
    await page.getByRole('link', { name: 'the findings', exact: true }).click();
    await page.waitForURL(origin + evidenceUrl + '#revised-findings');
    assert.equal(new URL(page.url()).pathname, evidenceUrl);
    assert.equal(new URL(page.url()).hash, '#revised-findings');
    assert.equal(await page.locator('[id="revised-findings"]').count(), 1);
    const image = page.locator('article img[alt="sensor.png"]');
    await image.evaluate(el => el.decode());
    assert.equal(await image.evaluate(el => el.naturalWidth), 1);
    const details = page.locator('article details.callout-question');
    assert.equal(await details.getAttribute('open'), null);
    await details.locator('summary').click();
    assert.notEqual(await details.getAttribute('open'), null);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    if (javaScriptEnabled) {
      await page.waitForFunction(() => !document.querySelector('#lattice-controls').disabled);
      await page.getByRole('searchbox').fill('Field Manual');
      await page.getByRole('button', { name: 'Search', exact: true }).click();
      await page.locator('#lattice-results a').waitFor();
      assert.equal(await page.locator('#lattice-results a').count(), 1);
      assert.ok((await page.locator('#lattice-results a').getAttribute('href')).startsWith(evidenceUrl));
      await page.getByRole('searchbox').fill('violet');
      await page.getByRole('button', { name: 'Search', exact: true }).click();
      await page.waitForFunction(expected => document.querySelector('#lattice-results a')?.getAttribute('href') === expected, evidenceUrl + '#revised-findings');
      await page.locator('#lattice-results a').click();
      assert.equal(new URL(page.url()).hash, '#revised-findings');
    }
    await context.close();
  }
  console.log('Vault browser acceptance: repaired canonical citation, final heading, decoded attachment and native callout interaction passed on desktop and mobile/no-JS');
} finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
