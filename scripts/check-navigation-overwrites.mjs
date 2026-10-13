import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const source = (title, heading, tags = 'Soil, Water') => `---\ntitle: ${JSON.stringify(title)}\ndate: 2026-01-02\ntags: [${tags}]\n---\n## ${heading}\n[[normal#Safe|Reference]]\n`;
for (const mode of ['root', 'standalone', 'details']) {
  const root = mkdtempSync(join(tmpdir(), 'lattice-navigation-output-'));
  const content = join(root, 'content');
  const posts = join(content, 'posts');
  const standalone = join(content, 'standalone');
  const details = join(root, 'details');
  const templates = join(root, 'templates');
  const output = join(root, 'dist');
  for (const directory of [posts, standalone, details, templates, join(content, 'data')]) mkdirSync(directory, { recursive: true });
  for (const [filename, heading] of [['normal', 'Safe'], [mode === 'details' ? 'near-page' : 'page', 'Safe'], ['later', 'Safe'], ['2026', 'Source Only'], ['archive', 'Source Only']]) {
    writeFileSync(join(posts, `${filename}.md`), source(filename, heading));
  }
  const overwritten = ['/posts/2026/', '/posts/archive/'];
  mkdirSync(join(content, 'static'));
  writeFileSync(join(content, 'static.md'), source('Static note', 'Source Only', 'Water'));
  writeFileSync(join(content, 'static/index.html'), '<h2 id="asset">Copied asset</h2>');
  overwritten.push('/static/');
  if (mode === 'details') {
    writeFileSync(join(details, 'soil.md'), source('Soil note', 'Source Only', 'Water'));
    writeFileSync(join(details, 'page.md'), source('Nearby tag page', 'Safe', 'Water'));
    overwritten.push('/tags/soil/');
  } else {
    writeFileSync(join(mode === 'root' ? content : standalone, 'tags.md'), source('Tags note', 'Source Only'));
    overwritten.push('/tags/');
  }
  writeFileSync(join(templates, 'page.html'), '{{content}}{{backlinks}}');
  for (const [name, label] of [['index', 'collection'], ['tag', 'tag'], ['tags', 'tags'], ['archive', 'archive']]) {
    writeFileSync(join(templates, `${name}.html`), `Generated ${label} {{content}}`);
  }
  writeFileSync(join(templates, '404.html'), '{{content}}');
  const collections = join(root, 'collections.cfg');
  const schema = 'title:String,date:Date,tags:Array[String]';
  const definitions = `[posts]\nschema = ${schema}\ndir = ${posts}\n` +
    (mode === 'details' ? `[tags]\nschema = ${schema}\ndir = ${details}\n` : '');
  writeFileSync(collections, definitions);
  const config = join(root, 'site.cfg');
  writeFileSync(config, `title = Navigation\nbase_url = https://example.test\npage_size = 1\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
  const run = (command, extra = []) => spawnSync(process.execPath,
    [cli, command, content, '-c', config, '--collections', collections, ...extra],
    { encoding: 'utf8', timeout: 30_000 });
  const check = run('check', ['--format', 'json']);
  assert.equal(check.status, 0, check.stdout + check.stderr);
  for (const [round, flags] of [[], [], ['--force']].entries()) {
    const build = run('build', flags);
    assert.equal(build.status, 0, build.stdout + build.stderr);
    if (round === 1) assert.ok(build.stdout.includes('[skip] posts/normal'), build.stdout);
    const entries = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'));
    for (const url of overwritten) {
      const authored = entries.find((entry) => entry.url === url && entry.kind !== 'collection_index');
      assert.ok(authored, `${mode}: missing authored entry ${url}`);
      const html = readFileSync(join(output, url.slice(1), 'index.html'), 'utf8');
      assert.ok((html.includes('Generated ') || html.includes('Copied asset')) && !html.includes('id="source-only"'), url);
      assert.deepEqual(authored.headings, [], `${mode}: stale headings at ${url}`);
      assert.deepEqual(authored.links, [], `${mode}: stale links at ${url}`);
    }
    for (const url of ['/posts/normal/', mode === 'details' ? '/posts/near-page/' : '/posts/page/', ...(mode === 'details' ? ['/tags/page/'] : [])]) {
      const entry = entries.find((entry) => entry.url === url);
      assert.deepEqual(entry.headings, [{ level: 2, id: 'safe', text: 'Safe' }]);
      assert.deepEqual(entry.links, [{ target: 'normal#Safe', url: '/posts/normal/#safe', text: 'Reference' }]);
      assert.ok(readFileSync(join(output, url.slice(1), 'index.html'), 'utf8').includes('id="safe"'));
    }
    for (const url of ['/posts/page/2/', '/tags/page/2/', '/tags/soil/page/2/', '/posts/2026/01/']) {
      assert.ok(existsSync(join(output, url.slice(1), 'index.html')), url);
      assert.equal(entries.some((entry) => entry.url === url), false);
    }
  }
  if (mode === 'details') {
    for (const filename of ['normal', 'near-page', 'later', '2026', 'archive']) {
      const path = join(posts, `${filename}.md`);
      writeFileSync(path, readFileSync(path, 'utf8').replace('tags: [Soil, Water]', 'tags: [Water]'));
    }
    const restored = run('build');
    assert.equal(restored.status, 0, restored.stdout + restored.stderr);
    const soil = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'))
      .find((entry) => entry.url === '/tags/soil/');
    assert.deepEqual(soil.headings, [{ level: 2, id: 'source-only', text: 'Source Only' }]);
    assert.deepEqual(soil.links, [{ target: 'normal#Safe', url: '/posts/normal/#safe', text: 'Reference' }]);
    assert.ok(readFileSync(join(output, 'tags/soil/index.html'), 'utf8').includes('id="source-only"'));
    const cached = run('build');
    assert.equal(cached.status, 0, cached.stdout + cached.stderr);
    assert.ok(cached.stdout.includes('[skip] tags/soil'), cached.stdout);
  }
  // Nested collection names cannot create authored pagination/month routes.
  writeFileSync(collections, definitions + `[posts/page]\nschema = ${schema}\ndir = ${details}\n`);
  const rejected = run('check', ['--format', 'json']);
  assert.equal(rejected.status, 1);
  assert.ok((rejected.stdout + rejected.stderr).includes('invalid collection name'));
}
console.log('Generated tag/archive output suppresses stale navigation across fresh, cached and forced builds');

const redirectFixture = (names) => {
  const root = mkdtempSync(join(tmpdir(), 'lattice-navigation-redirect-'));
  const content = join(root, 'content');
  const output = join(root, 'dist');
  const templates = join(root, 'templates');
  for (const name of [...names, 'standalone', 'data']) mkdirSync(join(content, name), { recursive: true });
  mkdirSync(templates);
  writeFileSync(join(templates, 'page.html'), '{{content}}{{backlinks}}');
  writeFileSync(join(templates, '404.html'), '{{content}}');
  const collections = join(root, 'collections.cfg');
  writeFileSync(collections, names.map((name) => `[${name}]\nschema = title:String\ndir = ${join(content, name)}\n`).join(''));
  const config = join(root, 'site.cfg');
  writeFileSync(config, `title = Redirects\nbase_url = https://example.test\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
  const run = (flags = []) => {
    const result = spawnSync(process.execPath, [cli, 'build', content, '-c', config, '--collections', collections, ...flags], { encoding: 'utf8', timeout: 30_000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return result.stdout;
  };
  const entry = (url) => JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8')).find((row) => row.url === url);
  const html = (url) => readFileSync(join(output, url.slice(1), 'index.html'), 'utf8');
  const masked = (url) => {
    assert.ok(html(url).includes('http-equiv="refresh"') && !html(url).includes('id="source-only"'));
    assert.deepEqual(entry(url).headings, []);
    assert.deepEqual(entry(url).links, []);
  };
  return { content, run, entry, html, masked };
};
for (const mode of ['collection', 'standalone', 'root', 'homepage']) {
  const fixture = redirectFixture(['notes']);
  const url = mode === 'collection' ? '/notes/self/' : mode === 'homepage' ? '/' : '/self/';
  const directory = mode === 'collection' ? 'notes' : mode === 'standalone' ? 'standalone' : '';
  const path = join(fixture.content, directory, mode === 'homepage' ? 'index.md' : 'self.md');
  const body = '## Source Only\n[[#Source Only|Reference]]\n';
  writeFileSync(path, `---\ntitle: Self\nredirect_from: [${JSON.stringify(url)}]\n---\n${body}`);
  for (const flags of [[], [], ['--force']]) { fixture.run(flags); fixture.masked(url); }
  writeFileSync(path, `---\ntitle: Self\n---\n${body}`);
  fixture.run();
  assert.ok(fixture.html(url).includes('id="source-only"') && !fixture.html(url).includes('http-equiv="refresh"'));
  assert.deepEqual(fixture.entry(url).headings, [{ level: 2, id: 'source-only', text: 'Source Only' }]);
  assert.deepEqual(fixture.entry(url).links, [{ target: '#Source Only', url: `${url}#source-only`, text: 'Reference' }]);
  const cached = fixture.run();
  if (mode === 'collection') assert.ok(cached.includes('[skip] notes/self'));
}
{
  // Collection order puts the redirect before the cached victim's processing.
  const fixture = redirectFixture(['first', 'second']);
  const sender = join(fixture.content, 'first/sender.md');
  writeFileSync(sender, '---\ntitle: Sender\n---\n## Sender\n');
  writeFileSync(join(fixture.content, 'second/victim.md'), '---\ntitle: Victim\n---\n## Source Only\n[[sender|Reference]]\n');
  fixture.run();
  assert.ok(fixture.run().includes('[skip] second/victim'));
  writeFileSync(sender, '---\ntitle: Sender\nredirect_from: ["/second/victim/"]\n---\n## Sender\n');
  assert.ok(fixture.run().includes('[skip] second/victim'));
  fixture.masked('/second/victim/');
  writeFileSync(sender, '---\ntitle: Sender\n---\n## Sender\n');
  fixture.run();
  assert.ok(fixture.html('/second/victim/').includes('id="source-only"'));
  assert.deepEqual(fixture.entry('/second/victim/').headings, [{ level: 2, id: 'source-only', text: 'Source Only' }]);
  assert.deepEqual(fixture.entry('/second/victim/').links, [{ target: 'sender', url: '/first/sender/', text: 'Reference' }]);
  assert.ok(fixture.run().includes('[skip] second/victim'));
}
console.log('Self redirects and earlier redirects suppress overwritten navigation and recover cached source HTML');
