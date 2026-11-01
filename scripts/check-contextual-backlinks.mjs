import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const cli=process.env.LATTICE_NATIVE_CLI??process.env.LATTICE_CLI??fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js',import.meta.url));
const root=mkdtempSync(join(tmpdir(),'lattice-contextual-'));
for(const d of ['content/notes','content/static','content/data','templates'])mkdirSync(join(root,d),{recursive:true});
writeFileSync(join(root,'collections.cfg'),'[notes]\ndir = content/notes\nschema = title:String\n');
writeFileSync(join(root,'site.cfg'),`title = Context\nbase_url = https://example.test\ntemplates_dir = templates\ncollections_file = collections.cfg\nwikilink_aliases = true\noutput_dir = ${root}/dist\n`);
const template='<html><body><h1>{{page_title}}</h1>{{reader_metadata}}{{body_no_h1}}{{?backlinks}}{{backlinks}}{{/?backlinks}}</body></html>';
writeFileSync(join(root,'templates/page.html'),template);
const put=(name,body,fields='')=>writeFileSync(join(root,'content/notes/'+name+'.md'),`---\ntitle: ${name}\n${fields}---\n${body}\n`);
put('target','Target body.','aliases: [Destination]\n');
put('source','## Reason & evidence\nUse [[Destination]] to inspect the & <b>public</b> result.\n\n## Later\nAnother [[target]] mention.');
put('hidden','Secret [[target]] text.','draft: true\n');
const run=(flags=[])=>{const r=spawnSync(process.env.LATTICE_NATIVE_CLI?cli:process.execPath,[...(process.env.LATTICE_NATIVE_CLI?[]:[cli]),'build','content','-c','site.cfg','--collections','collections.cfg',...flags],{cwd:root,encoding:'utf8'});assert.equal(r.status,0,r.stdout+r.stderr);return r.stdout;};
const read=()=>readFileSync(join(root,'dist/notes/target/index.html'),'utf8');
run();let html=read();assert.match(html,/class="backlink-context"/);assert.match(html,/href="\/notes\/source\/#reason/);assert.match(html,/Use Destination to inspect the &amp; public result/);assert.equal(html.includes('Secret'),false);assert.match(html,/Backlinks \(1\)/);
const first=html;const cached=run();assert.equal(read(),first);assert.match(cached,/unchanged/);run(['--force']);assert.equal(read(),first);
put('source','## Changed\n> A nested [[target]] reference with a new reason.\n\nRepeated [[Destination]].');run();html=read();assert.match(html,/#changed/);assert.match(html,/A nested target reference with a new reason/);assert.equal(html.includes('Use Destination'),false);
// A stripped H1 cannot become a section target, but its retained paragraph can be quoted.
put('source','# Omitted title\nA retained [[target]] paragraph.');run();html=read();assert.match(html,/href="\/notes\/source\/"/);assert.match(html,/A retained target paragraph/);
// Nested headings consume IDs; the enclosing top-level duplicate must be used.
put('source','## Repeat\n> ### Repeat\n> Earlier text.\n\n## Repeat\nA later [[Destination]] reference.');run();html=read();assert.match(html,/#repeat-3/);assert.match(html,/A later Destination reference/);
put('source','## Collision\nA retained [[target]] reference.\n\n<div id="collision">Duplicate heading ID</div>');run();html=read();assert.match(html,/href="\/notes\/source\/"/);assert.match(html,/A retained target reference/);
run(['--drafts']);assert.match(read(),/Secret target text/);run();assert.equal(read().includes('Secret'),false);
for(const wrapper of ['<!-- {{body_no_h1}} -->','<template>{{body_no_h1}}</template>']) {
 writeFileSync(join(root,'templates/page.html'),template.replace('{{body_no_h1}}',wrapper));run();assert.equal(read().includes('backlink-context'),false);
}
// The source page publishes no Markdown body: retain a page link, expose no excerpt.
writeFileSync(join(root,'templates/page.html'),'<html><body><h1>{{page_title}}</h1>{{reader_metadata}}{{?backlinks}}{{backlinks}}{{/?backlinks}}</body></html>');run();html=read();assert.match(html,/href="\/notes\/source\/"/);assert.equal(html.includes('backlink-context'),false);
writeFileSync(join(root,'templates/page.html'),template);run();assert.match(read(),/backlink-context/);
// Duplicate renderer blocks are ambiguous; skip them and select the next unique occurrence.
put('source','## First\nRepeated [[target]].\n\nRepeated [[target]].\n\n## Reliable\nUnique [[target]] reason.');run();html=read();assert.match(html,/#reliable/);assert.match(html,/Unique target reason/);assert.equal(html.includes('Repeated target'),false);
// A long Unicode excerpt is bounded and escapes source text rather than injecting markup.
put('source','## Why\n[[target]] '+ '🌱'.repeat(200) + ' & <b>tail</b>');run();html=read();const excerpt=html.match(/<p class="backlink-context">(.*?)<\/p>/s)[1];assert.equal([...excerpt].length,181);assert.equal(excerpt.endsWith('…'),true);assert.equal(excerpt.includes('tail'),false);
// Footnote references retain canonical navigation but cannot quote appended template content.
put('source','Text[^note].\n\n[^note]: Footnote [[target]] reason.');run();html=read();assert.match(html,/href="\/notes\/source\/"/);assert.equal(html.includes('backlink-context'),false);
put('source','## Restored\nA published [[target]] reference.');run();assert.match(read(),/backlink-context/);
// Identical template-only HTML is not renderer-origin publication.
put('source','A [[target]] reference.');
writeFileSync(join(root,'templates/page.html'),template.replace('{{body_no_h1}}','<p>A <a href="/notes/target/">target</a> reference.</p>\n'));run();assert.equal(read().includes('backlink-context'),false);
writeFileSync(join(root,'templates/page.html'),template);
for(const tag of ['iframe','xmp','noembed','noframes','textarea','noscript']) {
 put('source',`Before <${tag}>[[target]]</${tag}>.`);run();assert.equal(read().includes('backlink-context'),false,tag);
}
put('source','## Restored\nA published [[target]] reference.');run();assert.match(read(),/backlink-context/);
// A final static owner replaces the referrer; neither its private body nor link survives.
writeFileSync(join(root,'site.cfg'),readFileSync(join(root,'site.cfg'),'utf8')+'static_dir = notes\n');mkdirSync(join(root,'content/notes/source'),{recursive:true});writeFileSync(join(root,'content/notes/source/index.html'),'<p>Replacement</p>');run();html=read();assert.equal(html.includes('backlink-context'),false);assert.equal(html.includes('Backlinks (1)'),false);
console.log('Contextual backlinks: aliases, first retained block, nested references, escaping, draft/overwrite exclusion, omitted body and cached/forced parity passed');
