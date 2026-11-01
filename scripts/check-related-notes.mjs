import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,cpSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const native=process.env.LATTICE_NATIVE_CLI;
const repo=fileURLToPath(new URL('../',import.meta.url));
const cli=native??process.env.LATTICE_CLI??join(repo,'_build/js/debug/build/kurisu/lattice/cmd/main/main.js');
const root=mkdtempSync(join(tmpdir(),'lattice-related-'));
for(const dir of ['content/notes','content/static','content/data','templates'])mkdirSync(join(root,dir),{recursive:true});
const schema='title:String,related:Optional[Array[Ref[notes]]]';
const setSchema=value=>writeFileSync(join(root,'collections.cfg'),`[notes]\ndir = content/notes\nschema = ${value}\n`);
setSchema(schema);
writeFileSync(join(root,'site.cfg'),'title = Related\nbase_url = https://example.test\ntemplates_dir = templates\ncollections_file = collections.cfg\ncontent_index_file = content-index.json\nwikilink_aliases = true\noutput_dir = dist\n');
for(const name of ['page.html','wiki-navigation.html'])cpSync(join(repo,'examples/wiki_search',name),join(root,'templates',name));
writeFileSync(join(root,'templates/404.html'),'{{content}}');
const put=(slug,title,fields='',body='A public note.')=>writeFileSync(join(root,`content/notes/${slug}.md`),`---\ntitle: ${JSON.stringify(title)}\n${fields}---\n${body}\n`);
put('source','A reading guide','related: [second, first, source, second, draft]\n');
put('first','First & <careful> "title"','aliases: [Alternative]\n');put('second','Second choice');put('draft','Private recommendation','draft: true\n');
const run=(command='build',flags=[],status=0)=>{const r=spawnSync(native?cli:process.execPath,[...(native?[]:[cli]),command,'content','-c','site.cfg','--collections','collections.cfg',...flags],{cwd:root,encoding:'utf8',timeout:30000});assert.equal(r.status,status,r.stdout+r.stderr);return r;};
const read=slug=>readFileSync(join(root,`dist/notes/${slug}/index.html`),'utf8');
const related=html=>html.match(/<section class="related-notes"[^>]*>(.*?)<\/section>/s)?.[1]??'';
run('check');run();let html=read('source'),section=related(html);
assert.deepEqual([...section.matchAll(/href="([^"]+)"/g)].map(m=>m[1]),['/notes/second/','/notes/first/']);
assert.match(section,/First &amp; &lt;careful&gt; "title"/);assert.ok(!html.includes('Private recommendation'));assert.ok(!html.includes('<!--lattice-related-notes-->'));
assert.equal(related(read('first')),'');assert.ok(!read('first').includes('<section class="backlinks"'));
assert.deepEqual(JSON.parse(readFileSync(join(root,'dist/graph.json'))).edges,[]);
const first=html;run();assert.equal(read('source'),first);run('build',['--force']);assert.equal(read('source'),first);
put('first','Retitled destination','aliases: [Alternative]\n');run();assert.match(related(read('source')),/Retitled destination/);
run('build',['--drafts']);assert.match(related(read('source')),/Private recommendation/);run();assert.ok(!related(read('source')).includes('Private recommendation'));
// Related links do not become citations. An explicit body alias remains a canonical graph edge.
put('source','A reading guide','related: [first, second]\n','Read [[Alternative]].');run();
assert.deepEqual(JSON.parse(readFileSync(join(root,'dist/graph.json'))).edges.map(e=>e.target),['first']);
assert.match(read('first'),/class="backlinks"/);assert.ok(!read('second').includes('<section class="backlinks"'));
// The typed Ref contract remains canonical: aliases and missing slugs are actionable errors.
for(const target of ['Alternative','missing']){put('source','Guide',`related: [${target}]\n`);const r=run('check',['--format','json'],1);assert.match(r.stdout,/related/);const before=read('first');run('build',[],1);assert.equal(read('first'),before);}
put('source','Guide','related: [source, draft]\n');run();assert.equal(related(read('source')),'');
put('source','Guide','related: []\n');run();assert.equal(related(read('source')),'');
put('source','Guide');run();assert.equal(related(read('source')),'');
// Merely naming an untyped field related does not opt in.
setSchema('title:String,related:Optional[Array[String]]');put('source','Guide','related: [first]\n');run();assert.equal(related(read('source')),'');
setSchema('title:String,related:Optional[Ref[notes]]');put('source','Guide','related: first\n');run();assert.match(related(read('source')),/Retitled destination/);
setSchema(schema);put('source','Guide','related: [first, second]\n');
// Final static ownership removes recommendations to overwritten authored pages.
writeFileSync(join(root,'site.cfg'),readFileSync(join(root,'site.cfg'),'utf8')+'static_dir = notes\n');mkdirSync(join(root,'content/notes/first'),{recursive:true});writeFileSync(join(root,'content/notes/first/index.html'),'<p>Replacement</p>');run();
assert.deepEqual([...related(read('source')).matchAll(/href="([^"]+)"/g)].map(m=>m[1]),['/notes/second/']);
const final=read('source');run();assert.equal(read('source'),final);run('build',['--force']);assert.equal(read('source'),final);
console.log('Authored related notes: typed opt-in, canonical order, escaping, graph separation, draft/overwrite exclusion and rebuild parity passed');
