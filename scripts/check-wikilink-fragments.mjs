import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = mkdtempSync(join(tmpdir(), 'lattice-fragment-check-'));
const content = join(root, 'content');
const templates = join(root, 'templates');
const output = join(root, 'dist');
mkdirSync(content); mkdirSync(templates);
mkdirSync(join(content, "data"));
mkdirSync(join(content, "posts"));
const collections = join(root, "collections.cfg");
writeFileSync(collections, `[posts]\nschema = title:String,date:Date\ndir = ${join(content, "posts")}\n`);
const source = join(content, 'source.md');
const target = join(content, 'target.md');
const page = (body) => `---\ntitle: Fixture\n---\n${body}\n`;
writeFileSync(source, page('[[Target#Old Heading|read more]]'));
writeFileSync(target, page('## New Heading'));
writeFileSync(join(templates, 'page.html'), '<article>{{content}}</article>');
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Fragment Test\nbase_url = https://example.test\ntemplates_dir = ${templates}\noutput_dir = ${output}\ncollections_file = ${collections}\n`);
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const run = (command) => spawnSync(process.execPath, [cli, command, content, '-c', config, ...(command === 'check' ? ['--format', 'json'] : [])], { encoding: 'utf8', timeout: 30_000 });
const check = () => {
  const result = run('check');
  assert.ok(result.stdout.includes('{\n  "violations"'), result.stdout + result.stderr);
  const parsed = JSON.parse(result.stdout.slice(result.stdout.indexOf('{\n  "violations"')));
  return { ...result, violations: parsed.violations };
};
const missing = check();
assert.equal(missing.status, 1, `renamed heading must fail check: ${missing.stdout}${missing.stderr}`);
assert.deepEqual(missing.violations, [{ path: source, line: 4, column: 1, kind: 'broken_wikilink', message: "[[Target#Old Heading]]: fragment 'old-heading' not found in published page '/target/'" }]);
assert.ok(!existsSync(output), 'check must not create output/cache/manifest');
writeFileSync(source, page('[[Target.md#New Heading|alias]] [[#Here]]\n## Here'));
assert.equal(check().status, 0);
const built = run('build');
assert.equal(built.status, 0, built.stdout + built.stderr);
const snapshot = (dir) => Object.fromEntries(readdirSync(dir, { recursive: true }).filter((p) => statSync(join(dir, p)).isFile()).map((p) => [p, [readFileSync(join(dir, p)).toString('base64'), statSync(join(dir, p)).mtimeMs]]));
const before = snapshot(output);
writeFileSync(target, page('## Changed Again'));
assert.equal(check().status, 1, 'check must ignore stale published HTML/cache');
assert.deepEqual(snapshot(output), before, 'check must not touch existing output/cache/manifest');
// H1 and duplicate numbering must come from final HTML, independently of TOC.
writeFileSync(target, page('# Same\n## Same\n## Same\n###### Deep'));
const assertLink = (link, valid) => {
  writeFileSync(source, page(link));
  const result = check();
  assert.equal(result.status, valid ? 0 : 1, `${link}: ${result.stdout}${result.stderr}`);
  if (!valid) assert.ok(result.violations.some((v) => v.kind === 'broken_wikilink'));
};
for (const heading of ['same', 'same-2', 'same-3', 'deep']) assertLink(`[[Target#${heading}|read]]`, true);
assertLink('[[Target#same-4]]', false);
writeFileSync(join(templates, 'page.html'), '<main id="template-id">{{body_no_h1}}</main>');
assertLink('[[Target#same]]', false);
assertLink('[[Target#same-2]]', true);
assertLink('[[Target#template-id]]', true);
writeFileSync(join(templates, 'page.html'), '<main id="template-id">No content</main>');
assertLink('[[Target#same-2]]', false);
assertLink('[[Target#template-id]]', true);
writeFileSync(join(templates, 'page.html'), '{{content}}');
writeFileSync(target, page(`<div ID='actual' title='> id="attribute-fake"'></div>
<div id=unquoted></div><div id="entity&#45;id"></div>
<!-- <div id="comment-fake"></div> -->
<script>const fake = '<div id="script-fake"></div>';</script>
<textarea><div id="textarea-fake"></div></textarea>
<div id=" actual-space "></div><div id="first" id="duplicate-attribute"></div>`));
for (const id of ['actual', 'unquoted', 'entity-id', 'first']) assertLink(`[[Target#${id}]]`, true);
for (const id of ['attribute-fake', 'comment-fake', 'script-fake', 'textarea-fake', 'actual-space', 'duplicate-attribute']) assertLink(`[[Target#${id}]]`, false);
// Generated collection output wins over an authored page at the same URL.
writeFileSync(join(content, 'posts.md'), page('## Authored'));
writeFileSync(join(templates, 'index.html'), '<main id="generated">{{content}}</main>');
assertLink('[[Posts#Authored]]', false);
assertLink('[[Posts#generated]]', true);
// A static byte output wins over authored HTML.
mkdirSync(join(content, 'static'));
writeFileSync(join(content, 'static.md'), page('## Authored'));
writeFileSync(join(content, 'static/index.html'), '<div id="asset">Static</div>');
assertLink('[[Static#Authored]]', false);
assertLink('[[Static#asset]]', true);
// A self redirect is the final owner and has no authored heading IDs.
writeFileSync(target, '---\ntitle: Fixture\nredirect_from: [/target/]\n---\n## Redirected\n');
assertLink('[[Target#Redirected]]', false);
// Final tag template data must reflect removal of overwritten tagged pages.
writeFileSync(join(content, 'tags.md'), page('## Authored'));
writeFileSync(join(content, 'posts.md'), '---\ntitle: Shadow\ntags: [Lost]\n---\n## Gone\n');
writeFileSync(join(templates, 'tags.html'), '<main id="final-tags">{{content}}</main>');
assertLink('[[Tags#Authored]]', false);
assertLink('[[Tags#final-tags]]', true);
const tagSources = join(root, 'tag-sources');
mkdirSync(tagSources);
writeFileSync(join(tagSources, 'lost.md'), page('## Authored Lost'));
writeFileSync(collections, `[posts]\nschema = title:String,date:Date\ndir = ${join(content, 'posts')}\n[tags]\nschema = title:String\ndir = ${tagSources}\n`);
writeFileSync(join(templates, 'tag.html'), '<main id="count-{{tag_count}}">{{content}}</main>');
assertLink('[[Lost#count-0]]', true);
assertLink('[[Lost#count-1]]', false);
assertLink('[[Lost#Authored Lost]]', false);
// Surplus tag pagination retained over an authored route must use its final
// empty template, not either the authored heading or the preliminary tag count.
const surplus = join(root, 'surplus');
mkdirSync(surplus);
writeFileSync(join(surplus, '2.md'), page('## Surplus Authored'));
writeFileSync(join(content, 'tags.md'), '---\ntitle: Shadow Tags\ntags: [Lost]\n---\n## Gone\n');
writeFileSync(config, readFileSync(config, 'utf8').replace(`collections_file = ${collections}\n`, '') + 'page_size = 1\n' +
  [['posts', join(content, 'posts')], ['tags', tagSources], ['tags/lost/page', surplus]].map(([name, dir]) => `[[collections]]\nname = ${name}\ndir = ${dir}\nschema = title:String\n`).join(''));
assertLink('[[2#count-0]]', true);
assertLink('[[2#Surplus Authored]]', false);
assertLink('[[#Missing|same-page alias]]', false);
// Keep unrelated missing-page diagnostics alongside fragment errors.
writeFileSync(source, page('[[Missing]]\n[[Static#Authored|alias]]'));
const mixed = check();
assert.equal(mixed.status, 1);
assert.ok(mixed.violations.some((v) => v.message.includes("target 'Missing'")));
assert.ok(mixed.violations.some((v) => v.message.includes("fragment 'authored'")));
assert.deepEqual(snapshot(output), before, 'all checks remain nonpublishing');
console.log(`Final HTML fragments, templates, overwrites and read-only check passed (${root})`);
