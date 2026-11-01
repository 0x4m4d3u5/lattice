import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,statSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,extname} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createServer} from 'node:http';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';
const repo=fileURLToPath(new URL('../../',import.meta.url));
const root=mkdtempSync(join(tmpdir(),'lattice-local-graph-'));const site=join(root,'wiki');
const run=(file,args,cwd=repo)=>{const r=spawnSync(process.execPath,[join(repo,file),...args],{cwd,encoding:'utf8',timeout:60000});assert.equal(r.status,0,r.stdout+r.stderr);};
run('scripts/create-wiki.mjs',[site]);
const collections=join(site,'collections.cfg');writeFileSync(collections,readFileSync(collections,'utf8').replace('[Guides]','[guides]'));
const cli='_build/js/debug/build/kurisu/lattice/cmd/main/main.js';
const put=(name,body,fields='')=>writeFileSync(join(site,`content/guides/${name}.md`),`---\ntitle: ${name}\ndescription: Graph fixture\n${fields}---\n${body}`);
for(let i=0;i<35;i++)put(`neighbor-${String(i).padStart(2,'0')}`,'[[getting-started]]');
put('private-node','[[getting-started]]','draft: true\n');
run(cli,['build'],site);
const output=join(site,'dist');const target=join(output,'guides/getting-started/index.html');
const html=readFileSync(target,'utf8');assert.match(html,/data-local-graph=/);assert.ok(!html.includes('private-node'));
run(cli,['build'],site);assert.equal(readFileSync(target,'utf8'),html);
run(cli,['build','--force'],site);assert.equal(readFileSync(target,'utf8'),html);
const server=createServer((req,res)=>{try{let path=join(output,decodeURIComponent(new URL(req.url,'http://local').pathname));if(statSync(path).isDirectory())path=join(path,'index.html');res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.wasm':'application/wasm'})[extname(path)]??'application/octet-stream');res.end(readFileSync(path));}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const base=`http://127.0.0.1:${server.address().port}`;
const browser=await chromium.launch({chromiumSandbox:true,...(process.env.LATTICE_BROWSER_CHANNEL?{channel:process.env.LATTICE_BROWSER_CHANNEL}:{})});
try{
 for(const width of [1280,375]){
  const page=await browser.newPage({viewport:{width,height:900},reducedMotion:'reduce'});
  await page.goto(base+'/guides/getting-started/');await page.locator('.local-graph summary').click();await page.locator('.graph-canvas a').first().waitFor();
  assert.ok(await page.locator('.graph-canvas a').count()<=31);assert.ok(await page.locator('.graph-links a').count()<=30);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  const before=await page.locator('.graph-canvas > g').getAttribute('transform');await page.getByRole('button',{name:'Zoom in',exact:true}).click();assert.notEqual(await page.locator('.graph-canvas > g').getAttribute('transform'),before);
  await page.getByRole('button',{name:'Right',exact:true}).click();await page.getByRole('button',{name:'Reset view'}).click();assert.equal(await page.locator('.graph-canvas > g').getAttribute('transform'),'translate(0 0) scale(1)');
  const movable=page.locator('.graph-canvas a').nth(1);const oldPoint=await movable.getAttribute('transform');const box=await movable.locator('circle').boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.mouse.move(box.x+box.width/2+24,box.y+box.height/2+18,{steps:5});await page.mouse.up();assert.notEqual(await movable.getAttribute('transform'),oldPoint);assert.equal(new URL(page.url()).pathname,'/guides/getting-started/');
  const link=page.locator('.graph-canvas a').nth(1);await link.focus();await page.waitForFunction(()=>document.querySelector('.graph-canvas a.selected:not([aria-current])'));
  const destination=await link.getAttribute('href');await link.press('Enter');await page.waitForURL(destination);await page.locator('.local-graph summary').click();await page.locator('.graph-canvas a[aria-current="page"]').waitFor();
  assert.equal(new URL(await page.locator('.graph-canvas a[aria-current="page"]').getAttribute('href')).pathname,new URL(destination).pathname);
  await page.goBack();await page.waitForURL(base+'/guides/getting-started/');await page.locator('.local-graph summary').click();await page.locator('.graph-canvas a').first().waitFor();
  const timing=await page.evaluate(async()=>{const source=document.querySelector('[data-local-graph]').dataset.localGraph;const current=JSON.parse(source).nodes[0].url;const worker=new Worker('/static/search/graph-worker.js',{type:'module'});const times=[];for(let id=0;id<6;id++){const start=performance.now();await new Promise((resolve,reject)=>{worker.onmessage=resolve;worker.onerror=reject;worker.postMessage({id,source,current});});times.push(performance.now()-start);}worker.terminate();return {bytes:source.length,coldMs:times[0],warmMedianMs:times.slice(1).sort((a,b)=>a-b)[2]};});console.log('Browser worker round-trip',width,JSON.stringify(timing));
  await page.locator('.local-graph').screenshot({path:join(root,`graph-detail-${width}.png`)});
  await page.screenshot({path:join(root,`graph-${width}.png`),fullPage:true});await page.close();
 }
 const plain=await browser.newPage({javaScriptEnabled:false,viewport:{width:375,height:800}});await plain.goto(base+'/guides/getting-started/');await plain.locator('.local-graph summary').click();assert.ok(await plain.locator('.graph-links a').count()>0);assert.equal(await plain.locator('.graph-canvas').count(),0);await plain.close();
 const failed=await browser.newPage();await failed.route('**/graph-worker.js',route=>route.abort());await failed.goto(base+'/guides/getting-started/');await failed.locator('.local-graph summary').click();await failed.getByText('Graph unavailable; use the note links below.').waitFor();await failed.waitForFunction(()=>!document.querySelector('#lattice-controls').disabled);assert.ok(await failed.locator('.graph-links a').count()>0);await failed.close();
 // Final static ownership must remove the authored node and all incident edges.
 const conf=join(site,'content/lattice.conf');writeFileSync(conf,readFileSync(conf,'utf8')+'\nstatic_dir = guides\n');mkdirSync(join(site,'content/guides/neighbor-00'),{recursive:true});writeFileSync(join(site,'content/guides/neighbor-00/index.html'),'<p>Replacement</p>');run(cli,['build'],site);
 const graph=JSON.parse(readFileSync(join(output,'graph.json')));assert.ok(!graph.nodes.some(n=>n.slug==='neighbor-00'||n.slug==='private-node'));assert.ok(!graph.edges.some(e=>e.source==='neighbor-00'||e.target==='neighbor-00'));
 assert.ok(!readFileSync(target,'utf8').match(/<details class="local-graph"[\s\S]*?<\/details>/)?.[0].includes('neighbor-00'));
 console.log(`Local graph: bounded authored neighborhood, cached/forced parity, keyboard navigation/history, responsive/reduced-motion and noJS fallback, draft/static ownership passed. Screenshots: ${root}`);
}finally{await browser.close();await new Promise(r=>server.close(r));}
