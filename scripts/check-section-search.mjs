import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

// Fresh synthetic knowledge notes; no existing vault or user data is read.
const root = mkdtempSync(join(tmpdir(), 'lattice-section-search-'));
const content = join(root, 'content');
const posts = join(content, 'posts');
const standalone = join(content, 'standalone');
const templates = join(root, 'templates');
const output = join(root, 'dist');
for (const path of [posts, standalone, templates, join(content, 'data')]) mkdirSync(path, { recursive: true });
writeFileSync(join(content, 'index.md'), '---\ntitle: Knowledge\n---\nIntroductory notes.\n');
writeFileSync(join(posts, 'ops.md'), `---
title: Operations handbook
tags: [Reliability, Database]
---
# Operations

Scope: production infrastructure.

## Backups

Snapshot the volume nightly. Keep encrypted copies offsite.

## Recovery drills

Restore a **backup** into an isolated cluster. Verify checksums before promotion.

> ### Quoted reminder
> Practice regularly.

## Recovery drills

Record elapsed time after each exercise.

~~~markdown
## This is example code
~~~
`);
writeFileSync(join(standalone, 'guide.md'), '---\ntitle: Recovery checklist\ntags: [Reliability]\n---\n## Preparation\nAssign a commander. Check database backups.\n');
writeFileSync(join(standalone, 'hidden.md'), '---\ntitle: Hidden\ndraft: true\n---\n## Private drill\nSynthetic draft marker.\n');
writeFileSync(join(standalone, 'comments.md'), '---\ntitle: Comments\n---\n<!--\n\n## Private heading\n\nprivatemarker\n\n-->\n\n## Public\n\nvisible\n');
writeFileSync(join(standalone, 'closed.md'), '---\ntitle: Closed comments\n---\nBefore.\n\n<!--\n\n## Hidden\n\nprivatemarker\n\n<div>--></div>\n\n## Public\n\nvisible\n');
writeFileSync(join(standalone, 'references.md'), '---\ntitle: References\n---\n## Recovery\nSee procedure[^1].\n\n[^1]: Restore encrypted snapshots.\n');
writeFileSync(join(standalone, 'unfinished.md'), '---\ntitle: Unfinished formula\n---\n$$\nPreamble retained.\n\n## Preserved\nUnfinishedmarker read [[guide|the checklist]].\n\n~~~\n[[missing]]\n~~~\n');
// The generated /posts/ page supersedes this source; do not retrieve its text.
writeFileSync(join(content, 'posts.md'), '---\ntitle: Old index\n---\n## Obsolete\nObsolete recovery instructions.\n');
writeFileSync(join(templates, 'page.html'), '<article>{{body_no_h1}}</article>');
writeFileSync(join(templates, '404.html'), '{{content}}');
const collections = join(root, 'collections.cfg');
writeFileSync(collections, `[posts]\nschema = title:String,tags:Optional[Array[String]]\ndir = ${posts}\n`);
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Knowledge\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
const cli = process.env.LATTICE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const build = (flags = []) => {
  const result = spawnSync(process.execPath, [cli, 'build', content, '-c', config, '--collections', collections, ...flags], { encoding: 'utf8', timeout: 30_000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result.stdout;
};
const expected = [
  { heading: 'Operations', body: 'Scope: production infrastructure.' },
  { heading: 'Backups', body: 'Snapshot the volume nightly. Keep encrypted copies offsite.' },
  { heading: 'Recovery drills', body: 'Restore a backup into an isolated cluster. Verify checksums before promotion. Quoted reminder Practice regularly.' },
  { heading: 'Recovery drills', body: 'Record elapsed time after each exercise. ## This is example code' },
];
const verify = (drafts = false) => {
  const index = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'));
  const ops = index.find(entry => entry.title === 'Operations handbook');
  assert.deepEqual(ops.sections, expected); // Independent boundaries and rendered plaintext.
  assert.deepEqual(index.find(entry => entry.url === '/').sections, [{ heading: '', body: 'Introductory notes.' }]);
  assert.deepEqual(index.find(entry => entry.url === '/guide/').sections, [{ heading: 'Preparation', body: 'Assign a commander. Check database backups.' }]);
  assert.ok(index.filter(entry => entry.url === '/posts/').every(entry => entry.sections.length === 0));
  assert.equal(index.some(entry => entry.title === 'Hidden'), drafts);
  assert.deepEqual(index.find(entry => entry.url === '/comments/').sections, []);
  assert.deepEqual(index.find(entry => entry.url === '/closed/').sections, [
    { heading: '', body: 'Before.' }, { heading: 'Public', body: 'visible' },
  ]);
  assert.ok(!JSON.stringify(index.map(entry => entry.sections)).includes('privatemarker'));
  assert.deepEqual(index.find(entry => entry.url === '/references/').sections.map(section => section.heading), ['Recovery', 'Footnotes']);
  const unfinished = index.find(entry => entry.url === '/unfinished/');
  assert.deepEqual(unfinished.sections, [
    { heading: '', body: '$$ Preamble retained.' },
    { heading: 'Preserved', body: 'Unfinishedmarker read the checklist. [[missing]]' },
  ]);
  assert.ok(unfinished.links.some(link => link.url === '/guide/'));
  const html = readFileSync(join(output, 'unfinished/index.html'), 'utf8');
  assert.ok(html.includes('<h2 id="preserved">Preserved</h2>'));
  assert.ok(html.includes('<a href="/guide/">the checklist</a>'));
  return index;
};
build(); verify();
if (process.env.LATTICE_CLI) {
  console.log('Publisher section contract passed');
} else {
  const { search_content: search } = await import(pathToFileURL(fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.js', import.meta.url))));
  const index = verify();
  const result = JSON.parse(search(JSON.stringify(index), 'recovery', '["database"]', 10));
  assert.equal(result.error, null);
  assert.deepEqual(result.results.map(hit => [hit.url, hit.section_index]), [['/posts/ops/', 2], ['/posts/ops/', 3]]);
  assert.ok(!JSON.parse(search(JSON.stringify(index), 'obsolete', '[]', 10)).results.length);
  assert.deepEqual(JSON.parse(search(JSON.stringify(index), 'privatemarker', '[]', 10)).results, []);
  const preserved = JSON.parse(search(JSON.stringify(index), 'unfinishedmarker', '[]', 10));
  assert.equal(preserved.error, null);
  assert.deepEqual(preserved.results.map(hit => [hit.url, hit.section, hit.section_index]), [['/unfinished/', 'Preserved', 1]]);
  const reference = JSON.parse(search(JSON.stringify(index), 'encrypted', '[]', 10));
  const footnote = reference.results.find(hit => hit.url === '/references/');
  assert.equal(footnote?.section, 'Footnotes');
  assert.ok(footnote.snippet.includes('Restore encrypted snapshots.'));
  assert.ok(readFileSync(join(output, 'references/index.html'), 'utf8').includes('Restore encrypted snapshots.'));
  // Page citations must resolve to emitted files, including with body_no_h1.
  for (const hit of result.results) {
    const path = new URL(hit.url, 'https://example.test').pathname.slice(1);
    assert.ok(readFileSync(join(output, path, 'index.html'), 'utf8').includes('Restore a <strong>backup</strong>'));
  }
  assert.ok(build().includes('[skip] posts/ops'));
  verify();
  build(['--force']); verify();
  build(['--drafts']); verify(true);
  build(); verify();
  console.log('Published sections, cached/forced rebuilds, citations, filters and draft visibility passed');
}
