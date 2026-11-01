import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const cli=process.env.LATTICE_NATIVE_CLI ?? process.env.LATTICE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js',import.meta.url));
const root=mkdtempSync(join(tmpdir(),'lattice-reader-metadata-'));
for(const dir of ['content/notes','content/data','templates'])mkdirSync(join(root,dir),{recursive:true});
const output=join(root,'dist');
writeFileSync(join(root,'collections.cfg'),'[notes]\ndir = content/notes\nschema = title:String,date:Optional[Date],updated:Optional[Date],tags:Optional[Array[String]]\n');
writeFileSync(join(root,'site.cfg'),`title = Journal\nbase_url = https://example.test\ntemplates_dir = templates\ncollections_file = collections.cfg\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
const template='<html><head><title>{{title}}</title>{{head_meta}}</head><body><header><h1>{{page_title}}</h1>{{reader_metadata}}</header>{{body_no_h1}}{{?backlinks}}{{backlinks}}{{/?backlinks}}</body></html>';
writeFileSync(join(root,'templates/page.html'),template);
const source=(updated='2026-02-03')=>`---\ntitle: A | B & <C>\ndate: 2026-01-02\nupdated: ${updated}\ntags: [Research]\n---\n## Evidence\nA useful result.\n<div id="lattice-backlinks">Authored anchor</div>\n`;
const target=join(root,'content/notes/alpha.md');writeFileSync(target,source());
writeFileSync(join(root,'content/notes/beta.md'),'---\ntitle: Referrer\n---\n[[alpha#Evidence]] and [[alpha]].\n');
writeFileSync(join(root,'content/notes/hidden.md'),'---\ntitle: Hidden\ndraft: true\nupdated: 2026-02-04\n---\n[[alpha]].\n');
writeFileSync(join(root,'content/index.md'),'---\ntitle: Journal\nupdated: 2026-02-05\n---\nRoot note.\n');
const run=(command,flags=[],success=true)=>{
 const r=spawnSync(process.env.LATTICE_NATIVE_CLI ? cli : process.execPath,[...(process.env.LATTICE_NATIVE_CLI ? [] : [cli]),command,'content','-c','site.cfg','--collections','collections.cfg',...flags],{cwd:root,encoding:'utf8',timeout:30000});
 assert.equal(r.status===0,success,r.stdout+r.stderr);return r.stdout+r.stderr;
};
const read=path=>readFileSync(join(output,path),'utf8');
const objects=html=>[...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)].flatMap(m=>JSON.parse(m[1]));
const verify=updated=>{
 const html=read('notes/alpha/index.html');
 assert.ok(html.includes('Published <time datetime="2026-01-02">2026-01-02</time>'));
 assert.ok(html.includes(`Updated <time datetime="${updated}">${updated}</time>`));
 assert.ok(html.includes('href="/tags/research/">Research</a>'));
 assert.ok(html.includes('href="#lattice-backlinks-2">Backlinks (1)</a>'));
 assert.ok(html.includes('id="lattice-backlinks-2" tabindex="-1"'));
 assert.ok(html.includes('A | B &amp; &lt;C&gt;'));
 const article=objects(html).find(x=>x['@type']==='BlogPosting');
 assert.equal(article.datePublished,'2026-01-02');assert.equal(article.dateModified,updated);
 const feed=JSON.parse(read('notes/feed.json')).items.find(x=>x.url==='https://example.test/notes/alpha/');
 assert.equal(feed.date_published,'2026-01-02T00:00:00Z');assert.equal(feed.date_modified,updated+'T00:00:00Z');
 assert.ok(read('notes/feed.xml').includes(`<updated>${updated}T00:00:00Z</updated>`));
 assert.ok(read('sitemap.xml').includes(`<loc>https://example.test/notes/alpha/</loc>\n    <lastmod>${updated}</lastmod>`));
 const entries=JSON.parse(read('content-index.json'));
 assert.equal(entries.find(x=>x.url==='/notes/alpha/').updated,updated);
 assert.equal(entries.some(x=>x.title==='Hidden'),false);
 assert.equal('updated' in entries.find(x=>x.url==='/notes/beta/'),false);
 assert.equal(read('notes/beta/index.html').includes('reader-metadata'),false);
 const home=read('index.html');assert.ok(home.includes('Updated <time datetime="2026-02-05">'));
 assert.equal(home.includes('Published <time'),false);
};
run('check',['--format','json']);run('build');verify('2026-02-03');
const first=read('notes/alpha/index.html');run('build');verify('2026-02-03');assert.equal(read('notes/alpha/index.html'),first);
run('build',['--force']);verify('2026-02-03');
writeFileSync(target,source('2026-02-06'));run('build');verify('2026-02-06');
// Validation must not touch the already published output, even on cached sources.
const snapshot=()=>{const files={};const walk=(dir,prefix='')=>{for(const e of readdirSync(dir,{withFileTypes:true})){const p=join(prefix,e.name);if(e.isDirectory())walk(join(dir,e.name),p);else files[p]=readFileSync(join(dir,e.name)).toString('base64');}};walk(output);return files;};
const before=snapshot();
for(const bad of ['2025-12-31','2026-02-30','today','42','[2026-02-03]']){
 writeFileSync(target,source(bad));assert.match(run('check',['--format','json'],false),/updated/);run('build',[],false);assert.deepEqual(snapshot(),before);
}
writeFileSync(target,source('2026-01-02'));run('build');assert.equal(read('notes/alpha/index.html').includes('Updated <time'),false);
// A custom template that omits backlinks must not leave an unusable shortcut.
writeFileSync(join(root,'templates/page.html'),template.replace('{{backlinks}}',''));run('build');assert.equal(read('notes/alpha/index.html').includes('Backlinks (1)'),false);
for (const wrapper of ['<!-- {{backlinks}} -->', '<template>{{backlinks}}</template>']) {
 writeFileSync(join(root,'templates/page.html'),template.replace('{{backlinks}}',wrapper));run('build');assert.equal(read('notes/alpha/index.html').includes('Backlinks (1)'),false);
}
// DateTime publication retains its instant when an equal-day update normalizes
// to an earlier midnight. Subsequent authored days still advance the feed.
writeFileSync(join(root,'templates/page.html'),template);
writeFileSync(join(root,'collections.cfg'),'[notes]\ndir = content/notes\nschema = title:String,date:Optional[DateTime],updated:Optional[Date],tags:Optional[Array[String]]\n');
for (const [updated, expected] of [['2026-01-02','2026-01-02T12:00:00Z'],['2026-01-03','2026-01-03T00:00:00Z']]) {
 writeFileSync(target,source(updated).replace('date: 2026-01-02\n','date: 2026-01-02T12:00:00Z\n'));
 run('check');run('build');
 const verifyTimestamp=()=>{
  const feed=JSON.parse(read('notes/feed.json')).items.find(x=>x.url==='https://example.test/notes/alpha/');
  assert.equal(feed.date_published,'2026-01-02T12:00:00Z');assert.equal(feed.date_modified,expected);
  const entry=read('notes/feed.xml').split('<entry>').find(x=>x.includes('<id>https://example.test/notes/alpha/</id>'));
  assert.ok(entry.includes(`<updated>${expected}</updated>`));
  assert.equal(read('notes/alpha/index.html').includes('Updated <time'),updated!=='2026-01-02');
  assert.equal(objects(read('notes/alpha/index.html')).find(x=>x['@type']==='BlogPosting').dateModified,updated);
 };
 verifyTimestamp();const saved=snapshot();run('build');verifyTimestamp();assert.deepEqual(snapshot(),saved);
}
console.log('Reader metadata: authored dates, timestamp-safe feeds, validation, cache/rebuild, exports, drafts, tags, canonical backlinks and collision-safe/omitted targets passed');
