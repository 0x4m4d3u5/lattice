import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'lattice-passage-fragments-'));
const cli = process.env.LATTICE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
for (const path of ['content/notes', 'templates', 'data']) mkdirSync(join(root, path), { recursive: true });
const write = (path, text) => writeFileSync(join(root, path), text);
write('content/lattice.conf', 'title = Passages\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\ncontent_index_file = content-index.json\noutput_dir = dist\n');
write('collections.cfg', '[notes]\ndir = content/notes\nschema = title:String\n');
write('templates/404.html', '{{content}}');
write('content/notes/manual.md', '---\ntitle: Manual\n---\n# Manual\n\nOpening.\n\n## Café & tea\n\nFirst passage.\n\n> ### Café & tea\n> Nested reminder.\n\n## Café & tea\n\nSecond passage.[^1]\n\n[^1]: A footnote.\n');
const run = (command, flags = []) => {
  const result = spawnSync(process.execPath, [cli, command, ...flags], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
};
const sections = () => JSON.parse(readFileSync(join(root, 'dist/content-index.json'), 'utf8')).find(entry => entry.url === '/notes/manual/').sections;
const verify = expected => {
  assert.deepEqual(sections().map(section => section.fragment ?? null), expected);
  const html = readFileSync(join(root, 'dist/notes/manual/index.html'), 'utf8');
  for (const fragment of expected.filter(Boolean)) assert.ok(html.includes(`id="${fragment}"`));
};
const all = ['manual', 'caf-tea', 'caf-tea-3', null];
const trimmed = [null, 'caf-tea', 'caf-tea-3', null];
try {
  // H1 is not in the TOC. The nested duplicate consumes suffix 2 but is not a section.
  write('templates/page.html', '<article>{{content}}</article>');
  run('build'); verify(all);
  run('build'); verify(all);
  run('build', ['--force']); verify(all);
  write('templates/page.html', '<article>{{body_no_h1}}</article>');
  run('build'); verify(trimmed);
  // Equal template IDs are not proof that a source passage was published.
  write('templates/page.html', '<h2 id="caf-tea">Unrelated template heading</h2>');
  run('build'); verify([null, null, null, null]);
  for (const template of [
    '<!-- {{content}} -->', '<script>{{content}}</script>', '<textarea>{{content}}</textarea>',
    '<template>{{content}}</template>', '<select>{{content}}</select>', '<noscript>{{content}}</noscript>', '<plaintext>{{content}}', "<div data-text='{{content}}'></div>",
    '{{content | upper}}', '{{?tag_name}}{{content}}{{/?tag_name}}',
  ]) {
    write('templates/page.html', template);
    run('build');
    assert.deepEqual(sections().map(section => section.fragment ?? null), [null, null, null, null], template);
  }
  write('templates/page.html', '<div id="caf-tea"></div>{{content}}');
  run('build'); verify(['manual', null, 'caf-tea-3', null]);
  write('templates/page.html', '<div id="&#109anual"></div>{{content}}');
  run('build'); verify([null, null, null, null]);
  write('templates/page.html', '{{content}}{{content}}');
  run('build'); verify([null, null, null, null]);
  write('templates/page.html', '<!-- <h2 id="caf-tea">fake</h2> --><script>"<h2 id=\"caf-tea\">fake</h2>"</script>{{content}}');
  run('build'); verify(all);
  // Existing include/layout rendering carries offsets through child Body insertion.
  write('templates/base.html', '<html><body>{{body}}</body></html>');
  write('templates/part.html', '<article>{{body_no_h1}}</article>');
  write('templates/page.html', '{{layout: base.html}}{{include: part.html}}');
  run('build'); verify(trimmed);
  // Generated and static final owners suppress source passages entirely.
  mkdirSync(join(root, 'content/static'), { recursive: true });
  write('content/static.md', '---\ntitle: Static source\n---\n## Source\nOld text.\n');
  write('content/static/index.html', '<h2 id="source">Replacement</h2>');
  write('content/notes.md', '---\ntitle: Old directory\n---\n## Obsolete\nOld text.\n');
  run('build');
  const index = JSON.parse(readFileSync(join(root, 'dist/content-index.json'), 'utf8'));
  for (const url of ['/notes/', '/static/']) {
    const replacements = index.filter(entry => entry.url === url);
    assert.ok(replacements.length > 0);
    assert.ok(replacements.every(entry => entry.sections.length === 0));
  }
  rmSync(join(root, 'content/static/index.html'));
  run('build');
  const restored = JSON.parse(readFileSync(join(root, 'dist/content-index.json'), 'utf8'));
  assert.equal(restored.find(entry => entry.url === '/static/').sections[0].fragment, 'source');
  rmSync(join(root, 'templates/page.html'));
  run('build'); verify(all);
  const before = readFileSync(join(root, 'dist/content-index.json'), 'utf8');
  run('check');
  assert.equal(readFileSync(join(root, 'dist/content-index.json'), 'utf8'), before);
  console.log('Published passage fragments: renderer origins, H1, nested duplicates, templates, uniqueness, cache and final ownership passed');
} finally {
  rmSync(root, { recursive: true, force: true });
}
