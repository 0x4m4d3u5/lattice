import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Fresh synthetic content only; preserve the fixture for inspection after a run.
const root = mkdtempSync(join(tmpdir(), 'lattice-heading-links-'));
const content = join(root, 'content');
const posts = join(content, 'posts');
const output = join(root, 'dist');
const templates = join(root, 'templates');
mkdirSync(posts, { recursive: true });
mkdirSync(templates);
mkdirSync(join(content, 'standalone'));
writeFileSync(join(content, 'index.md'), '---\ntitle: Wiki\n---\n# Wiki\n\n## Wiki\n');
writeFileSync(join(content, 'standalone/manual.md'), '---\ntitle: Manual\ntoc: true\ntoc_depth: 2\n---\n- Install\n  ## Setup\n\n## Setup\n\n> ### Quoted\n\n###### Deep\n\n<h2 id="raw">Raw</h2>\n');
mkdirSync(join(content, "data"));
const alpha = join(posts, 'alpha.md');
writeFileSync(alpha, '---\ntitle: Garden\ndate: 2026-01-02\n---\n## Overview\n\nJump [[#Overview|here]].\n\nRead [[Beta.md#Planting & Care|care]] and [[Beta#planting-care-2|again]].\n\nExample ``[[missing]] ` literal``.\n');
writeFileSync(join(posts, 'beta.md'), '---\ntitle: Beta\ndate: 2026-01-03\n---\n## Planting & Care\n\n## Planting & Care\n\nphoto**syn**thesis uses H<sub>2</sub>O. Read [notes](/notes/), then `x`.\n\nphoto<mark>syn</mark>thesis. <abbr title="HyperText Markup Language">HTML</abbr>-based. <kbd>Ctrl</kbd>+<kbd>C</kbd>.\n\n<div>Temperature 10&#176;C. Plant &#x1F331;. A&#32;&#9;B.</div>\n\n<div title="comparison > metadata">Visible <!-- > hidden annotation -->prose.</div>\n\n<textarea><!-- visible</textarea><p>After textarea.</p>\n');
writeFileSync(join(templates, 'page.html'), '<article>{{table_of_contents}}{{content}}{{backlinks}}</article>');
writeFileSync(join(templates, '404.html'), '{{content}}');
const collections = join(root, 'collections.cfg');
writeFileSync(collections, `[posts]\nschema = title:String,date:Date\ndir = ${posts}\n`);
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Wiki Test\ncontent_index_file = content-index.json\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\noutput_dir = ${output}\n`);
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const run = (command, extra = []) => spawnSync(process.execPath,
  [cli, command, content, '-c', config, '--collections', collections, ...extra],
  { encoding: 'utf8', timeout: 30_000 });
const check = run('check', ['--format', 'json']);
assert.equal(check.status, 0, check.stdout + check.stderr);
assert.deepEqual(JSON.parse(check.stdout.slice(check.stdout.indexOf('{\n  "violations"'))).violations, []);
const build = run('build');
assert.equal(build.status, 0, build.stdout + build.stderr);
assert.ok(readFileSync(join(output, 'posts/alpha/index.html'), 'utf8').includes(
  '<p>Read <a href="/posts/beta/#planting-care">care</a> and <a href="/posts/beta/#planting-care-2">again</a>.</p>\n'));
assert.ok(readFileSync(join(output, 'posts/alpha/index.html'), 'utf8').includes(
  '<p>Example <code>[[missing]] ` literal</code>.</p>\n'));
assert.ok(readFileSync(join(output, 'posts/alpha/index.html'), 'utf8').includes('<p>Jump <a href="#overview">here</a>.</p>'));
assert.ok(!readFileSync(join(output, 'posts/alpha/index.html'), 'utf8').includes('href="/posts/alpha/#overview">Garden</a>'));
const beta = readFileSync(join(output, 'posts/beta/index.html'), 'utf8');
const expectedBody = 'Planting & Care Planting & Care photosynthesis uses H2O. Read notes, then x. photosynthesis. HTML-based. Ctrl+C. Temperature 10°C. Plant 🌱. A B. Visible prose. <!-- visible After textarea.';
const contentBody = () => JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'))
  .find((entry) => entry.slug === 'beta').body;
const contentHeadings = () => JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'))
  .find((entry) => entry.url === '/posts/beta/').headings;
const expectedHeadings = [
  { level: 2, id: 'planting-care', text: 'Planting & Care' },
  { level: 2, id: 'planting-care-2', text: 'Planting & Care' },
];
const contentLinks = (url) => JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'))
  .find((entry) => entry.url === url).links;
const expectedLinks = [
  { target: '#Overview', url: '/posts/alpha/#overview', text: 'here' },
  { target: 'Beta.md#Planting & Care', url: '/posts/beta/#planting-care', text: 'care' },
  { target: 'Beta#planting-care-2', url: '/posts/beta/#planting-care-2', text: 'again' },
];
assert.deepEqual(contentLinks('/posts/alpha/'), expectedLinks);
const assertCatalogs = () => {
  const entries = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'));
  assert.deepEqual(entries.find((e) => e.url === '/').headings,
    [{ level: 2, id: 'wiki-2', text: 'Wiki' }]);
  assert.deepEqual(entries.find((e) => e.url === '/manual/').headings, [
    { level: 2, id: 'setup', text: 'Setup' },
    { level: 2, id: 'setup-2', text: 'Setup' },
    { level: 3, id: 'quoted', text: 'Quoted' },
    { level: 6, id: 'deep', text: 'Deep' },
  ]);
  assert.deepEqual(entries.find((e) => e.url === '/posts/').headings, []);
  assert.ok(readFileSync(join(output, 'index.html'), 'utf8').includes('id="wiki-2"'));
  const manual = readFileSync(join(output, 'manual/index.html'), 'utf8');
  assert.ok(manual.includes('href="#setup"') && !manual.includes('href="#deep"'));
  assert.ok(manual.includes('id="setup"') && manual.includes('id="setup-2"') && manual.includes('id="raw"'));
};
assertCatalogs();
assert.deepEqual(contentHeadings(), expectedHeadings);
assert.equal(contentBody(), expectedBody);
const cached = run('build');
assert.equal(cached.status, 0, cached.stdout + cached.stderr);
assert.ok(cached.stdout.includes('[2 unchanged]'), cached.stdout);
assert.deepEqual(contentLinks('/posts/alpha/'), expectedLinks);
assertCatalogs();
assert.deepEqual(contentHeadings(), expectedHeadings);
assert.equal(contentBody(), expectedBody);

assert.ok(beta.includes('<h2 id="planting-care">Planting &amp; Care</h2>'));
assert.ok(beta.includes('<h2 id="planting-care-2">Planting &amp; Care</h2>'));
assert.ok(beta.includes('href="/posts/alpha/#overview">Garden</a>'));
assert.equal(beta.split('href="/posts/alpha/#overview">Garden</a>').length - 1, 1);
assert.deepEqual(JSON.parse(readFileSync(join(output, 'graph.json'), 'utf8')).edges,
  [{ source: 'alpha', target: 'beta' }]);
const index = readFileSync(join(output, 'posts/index.html'), 'utf8');
assert.ok(index.includes('<li><a href="/posts/beta/#planting-care">Beta</a> <code>Beta.md#Planting &amp; Care</code> (display: <code>care</code>)</li>'));
assert.ok(index.includes('<li><a href="/posts/beta/#planting-care-2">Beta</a> <code>Beta#planting-care-2</code> (display: <code>again</code>)</li>'));
assert.ok(index.includes('<li><a href="/posts/alpha/#overview">here</a> <code>#Overview</code> (display: <code>here</code>)</li>'));
const manifest = JSON.parse(readFileSync(join(output, '.lattice-manifest.json'), 'utf8'));
assert.deepEqual(manifest.entries.find((entry) => entry.src === alpha).targets, ['beta']);
// Removing a fragment-bearing reference must invalidate cached target backlinks.
writeFileSync(alpha, '---\ntitle: Garden\ndate: 2026-01-02\n---\nNo references.\n');
const incremental = run('build');
assert.equal(incremental.status, 0, incremental.stdout + incremental.stderr);
assert.deepEqual(contentLinks('/posts/alpha/'), []);
const updatedBeta = readFileSync(join(output, 'posts/beta/index.html'), 'utf8');
assert.ok(!updatedBeta.includes('href="/posts/alpha/#overview">Garden</a>'));
assert.deepEqual(JSON.parse(readFileSync(join(output, 'graph.json'), 'utf8')).edges, []);
const full = run('build', ['--force']);
assert.equal(full.status, 0, full.stdout + full.stderr);
assert.deepEqual(contentLinks('/posts/alpha/'), []);
assertCatalogs();
assert.deepEqual(contentHeadings(), expectedHeadings);
assert.equal(readFileSync(join(output, 'posts/beta/index.html'), 'utf8'), updatedBeta);
assert.equal(contentBody(), expectedBody);
// Existing guards allow authored and generated entries to share this URL.
for (const directory of [content, join(content, 'standalone')]) {
  const source = join(directory, 'posts.md');
  writeFileSync(source, '---\ntitle: Authored Posts\n---\n## Authored Section\n[[Beta|Reference]]\n');
  const collisionCheck = run('check', ['--format', 'json']);
  assert.equal(collisionCheck.status, 0, collisionCheck.stdout + collisionCheck.stderr);
  const collisionBuild = run('build', ['--force']);
  assert.equal(collisionBuild.status, 0, collisionBuild.stdout + collisionBuild.stderr);
  const shared = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'))
    .filter((entry) => entry.url === '/posts/');
  assert.equal(shared.length, 2);
  assert.deepEqual(shared.map((entry) => entry.headings), [[], []]);
  assert.deepEqual(shared.map((entry) => entry.links), [[], []]);
  const finalHtml = readFileSync(join(output, 'posts/index.html'), 'utf8');
  assert.ok(finalHtml.includes('<h2>Wikilink Graph</h2>'));
  assert.ok(!finalHtml.includes('id="authored-section"'));
  unlinkSync(source);
}
// Missing pages still produce a strict check diagnostic using the authored target.
writeFileSync(alpha, '---\ntitle: Garden\ndate: 2026-01-02\n---\n[[Missing#Intro]]\n');
const invalid = run('check', ['--format', 'json']);
assert.equal(invalid.status, 1, invalid.stdout + invalid.stderr);
assert.deepEqual(JSON.parse(invalid.stdout.slice(invalid.stdout.indexOf('{\n  "violations"'))).violations, [{
  path: alpha, line: 5, column: 1, kind: 'broken_wikilink',
  message: "[[Missing#Intro]]: target 'Missing#Intro' not found in page index",
}]);
console.log(`CLI cross-note headings, backlinks, graph, content text and diagnostic passed (${root})`);
