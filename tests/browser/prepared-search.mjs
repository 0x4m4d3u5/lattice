import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { chromium } from 'playwright';
const root = new URL('../../', import.meta.url);
const files = {
  '/worker.js': ['examples/wiki_search/worker.js', 'text/javascript'],
  '/host.js': ['examples/prepared_search/host.mjs', 'text/javascript'],
  '/renderer.wasm': ['_build/wasm-gc/debug/build/kurisu/lattice/examples/prepared_search/prepared_search.wasm', 'application/wasm'],
};
const entry = word => JSON.stringify([{ title: word, url: `/${word}/`, tags: [], sections: [{ heading: word, body: word }] }]);
let release;
const server = createServer(async (req, res) => {
  if (req.url === '/') { res.end('<!doctype html><title>Prepared worker tests</title>'); return; }
  if (req.url === '/slow') await new Promise(resolve => { release = resolve; });
  if (files[req.url]) {
    const [path, type] = files[req.url]; res.setHeader('content-type', type); res.end(readFileSync(new URL(path, root))); return;
  }
  res.setHeader('content-type', 'application/json');
  res.end(req.url === '/invalid' ? '[{}]' : entry(req.url === '/slow' ? 'obsolete' : req.url.slice(1)));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ chromiumSandbox: true });
try {
  const page = await browser.newPage(); await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.evaluate(() => {
    window.events = []; window.worker = new Worker('/worker.js', { type: 'module' });
    worker.onmessage = ({ data }) => events.push(data);
  });
  const send = data => page.evaluate(data => worker.postMessage(data), data);
  const wait = async (id, type) => { await page.waitForFunction(({id,type}) => events.some(x => x.id === id && x.type === type), {id,type}); return page.evaluate(({id,type}) => events.find(x => x.id === id && x.type === type), {id,type}); };
  await send({id:1,type:'load',indexUrl:'/first'}); await wait(1,'ready');
  for (let id=2;id<5;id++) { await send({id,type:'search',query:'first',tags:[]}); assert.equal((await wait(id,'results')).results[0].url,'/first/'); }
  await send({id:5,type:'load',indexUrl:'/invalid'}); await wait(5,'error');
  await send({id:6,type:'search',query:'first',tags:[]}); await wait(6,'error');
  await send({id:7,type:'load',indexUrl:'/slow'});
  while (!release) await new Promise(resolve => setTimeout(resolve,10));
  await send({id:8,type:'load',indexUrl:'/second'}); await wait(8,'ready'); release();
  await send({id:9,type:'search',query:'second',tags:[]}); assert.equal((await wait(9,'results')).results[0].url,'/second/');
  await send({id:10,type:'search',query:'first',tags:[]}); assert.equal((await wait(10,'results')).results.length,0);
  await page.waitForTimeout(100);
  assert.equal(await page.evaluate(() => events.some(x => x.id===7)),false,'obsolete load must not publish state');
  await page.evaluate(() => worker.terminate());
  console.log('Prepared browser worker repeated queries, failed replacement and racing loads passed');
} finally { release?.(); await browser.close(); await new Promise(resolve => server.close(resolve)); }
