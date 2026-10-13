import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, statSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const fixture = (inline = false) => {
  const root = mkdtempSync(join(tmpdir(), 'lattice-final-tags-'));
  const content = join(root, 'content'), templates = join(root, 'templates'), output = join(root, 'dist');
  for (const directory of ['posts', 'standalone', 'page', 'data']) mkdirSync(join(content, directory), { recursive: true });
  mkdirSync(templates);
  for (const template of ['page', 'index', 'tag', 'tags', '404']) writeFileSync(join(templates, `${template}.html`), '{{content}}');
  const note = (path, title, tags) => writeFileSync(join(content, path), `---\ntitle: ${title}\ntags: ${JSON.stringify(tags)}\n---\n## Survives\n`);
  const configure = (extra = '', collections = ['posts']) => {
    writeFileSync(join(root, 'collections.cfg'), collections.map((name) => `[${name}]\nschema = title:String,tags:Array[String]\ndir = ${join(content, name)}\n`).join(''));
    writeFileSync(join(root, 'site.cfg'), `title = Final tags\nbase_url = https://example.test\npage_size = 1\ncontent_index_file = content-index.json\ntemplates_dir = ${templates}\ncollections_file = ${join(root, 'collections.cfg')}\noutput_dir = ${output}\n${extra}`);
  };
  const run = (command = 'build', flags = []) => spawnSync(process.execPath, [cli, command, content, '-c', join(root, 'site.cfg'), ...(inline ? [] : ['--collections', join(root, 'collections.cfg')]), ...flags], { encoding: 'utf8', timeout: 30_000 });
  return { root, content, output, note, configure, run };
};
const snapshot = (directory) => {
  const files = {};
  const visit = (path, prefix = '') => {
    if (!existsSync(path)) return;
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const relative = prefix + entry.name;
      if (entry.isDirectory()) visit(join(path, entry.name), relative + '/');
      else files[relative] = readFileSync(join(path, entry.name)).toString('base64');
    }
  };
  visit(directory);
  return files;
};
for (const which of process.argv[2] ? [process.argv[2]] : ['asset', 'search', 'empty', 'all-empty', 'validation', 'inline-tag', 'inline-index']) {
if (which === 'asset' || which === 'search') {
  const f = fixture();
  f.note('posts/catalog.md', 'Catalog', ['Knowledge']);
  f.note('posts/survivor.md', 'Survivor', ['Knowledge']);
  f.note('standalone/posts.md', 'Shadow', ['Knowledge']);
  if (which === 'asset') {
    mkdirSync(join(f.content, 'tags/knowledge/page'), { recursive: true });
    writeFileSync(join(f.content, 'tags/knowledge/page/3'), 'Final static file');
    mkdirSync(join(f.content, 'tags/keep/empty'), { recursive: true });
    f.configure('static_dir = tags\n');
  } else f.configure('search_index_file = tags/knowledge/page/3\n');
  const result = f.run();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  for (const flags of [[], ['--force']]) {
    const rebuilt = f.run('build', flags);
    assert.equal(rebuilt.status, 0, rebuilt.stdout + rebuilt.stderr);
  }
  assert.ok(readFileSync(join(f.output, 'tags/knowledge/page/3'), 'utf8').includes(which === 'asset' ? 'Final static file' : 'Catalog'));
  if (which === 'asset') assert.ok(statSync(join(f.output, 'tags/keep/empty')).isDirectory());
} else if (which === 'empty' || which === 'all-empty') {
  const f = fixture();
  if (which === 'empty') {
    f.note('posts/catalog.md', 'Catalog', ['Mixed']);
    f.note('posts/survivor.md', 'Survivor', ['Other', 'Mixed']);
  }
  f.note('standalone/posts.md', 'Shadow', ['Exclusive', 'Extra', ...(which === 'empty' ? ['Mixed'] : [])]);
  f.configure(which === 'all-empty' ? 'search_index_file = tags/page/2\n' : '');
  for (const flags of [[], [], ['--force']]) {
    const result = f.run('build', flags);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const index = readFileSync(join(f.output, 'tags/index.html'), 'utf8');
    assert.ok(!index.includes('Exclusive') && !index.includes('Extra'));
    for (const tag of ['exclusive', 'extra']) {
      const primary = readFileSync(join(f.output, `tags/${tag}/index.html`), 'utf8');
      assert.ok(primary.includes('0 page(s)') && !primary.includes('Shadow'));
    }
    if (which === 'empty') {
      assert.ok(index.includes('Mixed</a> (2)') && index.includes('Page 1 of 2'));
      const second = readFileSync(join(f.output, 'tags/page/2/index.html'), 'utf8');
      assert.ok(second.includes('Other</a> (1)') && !second.includes('>Next</a>'));
      assert.equal(existsSync(join(f.output, 'tags/page/3/index.html')), false);
    } else {
      assert.ok(index.includes('No tags found.') && !index.includes('>Next</a>'));
      assert.ok(readFileSync(join(f.output, 'tags/page/2'), 'utf8').includes('Shadow'));
    }
  }
} else if (which === 'inline-tag' || which === 'inline-index') {
  for (const indexed of process.argv[3] ? [process.argv[3] === 'true'] : [false, true]) {
    const f = fixture(true);
    const collection = which === 'inline-tag' ? 'tags/knowledge/page' : 'tags/page';
    const url = `/${collection}/2/`;
    f.note('posts/catalog.md', 'Catalog', ['Knowledge']);
    f.note('standalone/posts.md', 'Shadow', ['Knowledge', 'Exclusive']);
    f.note('page/2.md', 'Note Two', ['Other']);
    const metaTemplate = '<head>{{head_meta}}</head><div data-url="{{url}}" data-page-url="{{page_url}}" data-page="{{page_num}}" data-total="{{total_pages}}">{{content}}</div>';
    for (const template of ['tag', 'tags']) writeFileSync(join(f.root, 'templates', `${template}.html`), metaTemplate);
    writeFileSync(join(f.root, 'site.cfg'), `title = Inline ownership\nbase_url = https://example.test\npage_size = 1\ntemplates_dir = ${join(f.root, 'templates')}\noutput_dir = ${f.output}\n` +
      (indexed ? 'content_index_file = content-index.json\n' : '') +
      `[[collections]]\nname = posts\ndir = ${join(f.content, 'posts')}\nschema = title:String,tags:Array[String]\n[[collections]]\nname = ${collection}\ndir = ${join(f.content, 'page')}\nschema = title:String,tags:Array[String]\n`);
    const checked = f.run('check', ['--format', 'json']);
    assert.equal(checked.status, 0, checked.stdout + checked.stderr);
    const html = (path) => readFileSync(join(f.output, path), 'utf8');
    const headings = () => {
      if (!indexed) { assert.equal(existsSync(join(f.output, 'content-index.json')), false); return; }
      return JSON.parse(html('content-index.json')).find((entry) => entry.url === url).headings;
    };
    for (const [round, flags] of [[], [], ['--force']].entries()) {
      const result = f.run('build', flags);
      assert.equal(result.status, 0, result.stdout + result.stderr);
      if (round === 1) assert.ok(result.stdout.includes('[skip] posts/catalog'));
      const retained = html(`${collection}/2/index.html`);
      assert.ok(!retained.includes('id="survives"') && !retained.includes('Note Two'));
      assert.ok(retained.includes(which === 'inline-tag' ? '0 page(s)' : 'No tags found.'));
      assert.ok(retained.includes(`rel="canonical" href="https://example.test${url}"`));
      assert.ok(retained.includes(`data-url="${url}" data-page-url="${url}" data-page="" data-total=""`));
      assert.ok(!retained.includes('class="pagination"') && !retained.includes('>Next</a>') && !retained.includes('>Previous</a>') && !retained.includes('Page 1 of') && !retained.includes('Page 2 of'));
      const index = html('tags/index.html');
      assert.ok(index.includes('Knowledge</a> (1)') && !index.includes('Other</a>') && !index.includes('Exclusive</a>'));
      assert.ok(!index.includes('>Next</a>'));
      const knowledge = html('tags/knowledge/index.html');
      assert.ok(knowledge.includes('<li><a href="/posts/catalog/">Catalog</a> <code>catalog</code></li>') && !knowledge.includes('Shadow') && !knowledge.includes('Note Two') && !knowledge.includes('>Next</a>'));
      assert.ok(html('tags/other/index.html').includes('0 page(s)') && !html('tags/other/index.html').includes('Note Two'));
      assert.equal(existsSync(join(f.output, 'tags/page/3/index.html')), false);
      if (which === 'inline-tag') assert.equal(existsSync(join(f.output, 'tags/page/2/index.html')), false);
      if (indexed) assert.deepEqual(headings(), []);
    }
    // The built-in fallback must use the retained destination's canonical URL.
    for (const template of ['tag', 'tags', 'index']) unlinkSync(join(f.root, 'templates', `${template}.html`));
    const fallback = f.run('build', ['--force']);
    assert.equal(fallback.status, 0, fallback.stdout + fallback.stderr);
    const emptyFallback = html(`${collection}/2/index.html`);
    assert.ok(emptyFallback.includes(`rel="canonical" href="https://example.test${url}"`));
    assert.ok(!emptyFallback.includes('class="pagination"') && !emptyFallback.includes('Page 1 of') && !emptyFallback.includes('Page 2 of'));
    // Remove all declarations reserving the surplus route, then check recovery.
    f.note('standalone/posts.md', 'Shadow', []);
    if (which === 'inline-index') f.note('page/2.md', 'Note Two', []);
    for (const [round, flags] of [[], [], ['--force']].entries()) {
      const result = f.run('build', flags);
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.ok(html(`${collection}/2/index.html`).includes('id="survives"'));
      if (round === 1) assert.ok(result.stdout.includes(`[skip] ${collection}/2`));
      if (indexed) assert.deepEqual(headings(), [{ level: 2, id: 'survives', text: 'Survives' }]);
      if (which === 'inline-tag') {
        assert.ok(html('tags/other/index.html').includes(`<li><a href="${url}">Note Two</a> <code>2</code></li>`));
        assert.ok(html('tags/index.html').includes('href="/tags/page/2/">Next</a>'));
        assert.ok(html('tags/page/2/index.html').includes('Other</a> (1)'));
      } else assert.ok(!html('tags/index.html').includes('>Next</a>') && !html('tags/index.html').includes('Other</a>'));
    }
  }
} else if (which === 'validation') {
  const f = fixture();
  const ordinary = ['C#', 'C++', 'Guides/Getting Started', 'a..b', 'safe/.hidden', 'safe/...'];
  f.note('posts/catalog.md', 'Catalog', ordinary);
  f.configure();
  assert.equal(f.run().status, 0);
  const indexed = JSON.parse(readFileSync(join(f.output, 'content-index.json'), 'utf8'));
  assert.deepEqual(indexed.find((entry) => entry.url === '/posts/catalog/').tags, ordinary);
  assert.ok(readFileSync(join(f.output, 'tags/guides/getting-started/index.html'), 'utf8').includes('Catalog'));
  const before = snapshot(f.output);
  assert.ok(Object.keys(before).some((path) => path.includes('cache')) && Object.keys(before).some((path) => path.includes('manifest')));
  for (const tag of ['.', '..', './Guide', 'Guide/../Other', 'Guide\\..\\Other', '..md', '...MD', 'Guides/..MD', 'Guides/...MD']) {
    f.note('posts/catalog.md', 'Catalog', [tag]);
    for (const command of ['check', 'build']) {
      const result = f.run(command, command === 'check' ? ['--format', 'json'] : ['--force']);
      assert.equal(result.status, 1, `${command}: ${tag}: ${result.stdout}${result.stderr}`);
      assert.ok((result.stdout + result.stderr).includes('dot path component'));
      assert.deepEqual(snapshot(f.output), before, `${command}: ${tag}: mutated published output/cache/manifest`);
    }
  }
  // A traversal alias must fail before a first publication too.
  const fresh = fixture();
  fresh.note('posts/catalog.md', 'Catalog', ['..']);
  fresh.note('standalone/posts.md', 'Shadow', ['..']);
  fresh.note('page/2.md', 'Note Two', ['Knowledge']);
  fresh.configure('', ['posts', 'page']);
  for (const command of ['check', 'build']) {
    const result = fresh.run(command);
    assert.equal(result.status, 1);
    assert.ok((result.stdout + result.stderr).includes('dot path component'));
    assert.equal(existsSync(fresh.output), false);
  }
}
console.log(`${which} final tag plan passed`);
}
