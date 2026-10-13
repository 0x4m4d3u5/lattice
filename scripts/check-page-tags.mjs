import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
for (const field of ['tags', 'topics']) {
  const root = mkdtempSync(join(tmpdir(), 'lattice-page-tags-'));
  const content = join(root, 'content');
  const posts = join(content, 'posts');
  const standalone = join(content, 'standalone');
  const templates = join(root, 'templates');
  const output = join(root, 'dist');
  for (const directory of [posts, standalone, templates, join(content, 'data')]) mkdirSync(directory, { recursive: true });
  const tagged = (title, tags) => `---\ntitle: ${title}\n${field}: ${tags}\n---\n## Guide\nUseful knowledge.\n`;
  writeFileSync(join(posts, 'catalog.md'), tagged('Catalog', '[Knowledge, AI]'));
  writeFileSync(join(content, 'index.md'), tagged('Wiki', '[Knowledge]'));
  writeFileSync(join(standalone, 'manual.md'), tagged('Manual', '[" AI ", Knowledge, AI]'));
  writeFileSync(join(standalone, 'plain.md'), '---\ntitle: Plain\n---\nNo tags.\n');
  writeFileSync(join(templates, 'page.html'), '{{content}}');
  writeFileSync(join(templates, '404.html'), '{{content}}');
  const collections = join(root, 'collections.cfg');
  writeFileSync(collections, `[posts]\nschema = title:String,${field}:Optional[Array[String]]\ndir = ${posts}\n`);
  const config = join(root, 'site.cfg');
  writeFileSync(config, `title = Wiki\nbase_url = https://example.test\ntags_field = ${field}\ntemplates_dir = ${templates}\ncollections_file = ${collections}\ncontent_index_file = content-index.json\noutput_dir = ${output}\n`);
  const run = (command, flags = []) => {
    const result = spawnSync(process.execPath, [cli, command, content, '-c', config, '--collections', collections, ...flags], { encoding: 'utf8', timeout: 30_000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    return result.stdout;
  };
  const verify = (manualTags = ['AI', 'Knowledge']) => {
    for (const filename of ['search-index.json', 'content-index.json']) {
      const entries = JSON.parse(readFileSync(join(output, filename), 'utf8'));
      assert.deepEqual(entries.find((entry) => entry.url === '/posts/catalog/').tags, ['Knowledge', 'AI']);
      assert.deepEqual(entries.find((entry) => entry.url === '/').tags, ['Knowledge']);
      assert.deepEqual(entries.find((entry) => entry.url === '/manual/').tags, manualTags);
      assert.deepEqual(entries.find((entry) => entry.url === '/plain/').tags, []);
      assert.deepEqual(entries.filter((entry) => entry.tags.includes('Knowledge')).map((entry) => entry.url).sort(),
        ['/', '/manual/', '/posts/catalog/']);
    }
    const manual = readFileSync(join(output, 'manual/index.html'), 'utf8');
    assert.equal(manual.includes('href="/tags/ai/">AI</a>'), manualTags.includes('AI'));
    assert.ok(manual.includes('href="/tags/knowledge/">Knowledge</a>'));
    const knowledge = readFileSync(join(output, 'tags/knowledge/index.html'), 'utf8');
    for (const row of ['<li><a href="/">Wiki</a> <code>index</code></li>', '<li><a href="/manual/">Manual</a> <code>manual</code></li>', '<li><a href="/posts/catalog/">Catalog</a> <code>catalog</code></li>']) {
      assert.equal(knowledge.split(row).length - 1, 1);
    }
  };
  run('check', ['--format', 'json']);
  run('build'); verify();
  assert.ok(run('build').includes('[skip] posts/catalog')); verify();
  run('build', ['--force']); verify();
  writeFileSync(join(standalone, 'manual.md'), tagged('Manual', '[Knowledge]'));
  run('build'); verify(['Knowledge']);
  run('build', ['--force']); verify(['Knowledge']);
  writeFileSync(join(content, 'index.md'), tagged('Wiki', '[RootOnly]'));
  writeFileSync(join(standalone, 'manual.md'), tagged('Manual', '[ManualOnly]'));
  writeFileSync(join(standalone, 'hidden.md'), `---\ntitle: Hidden\ndraft: true\n${field}: [Secret]\n---\nHidden knowledge.\n`);
  run('check', ['--format', 'json']);
  for (const flags of [[], [], ['--force'], ['--drafts'], [], ['--force']]) {
    run('build', flags);
    assert.ok(readFileSync(join(output, 'tags/rootonly/index.html'), 'utf8').includes('<li><a href="/">Wiki</a> <code>index</code></li>'));
    assert.ok(readFileSync(join(output, 'tags/manualonly/index.html'), 'utf8').includes('<li><a href="/manual/">Manual</a> <code>manual</code></li>'));
    const entries = JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8'));
    assert.equal(entries.some((entry) => entry.url === '/hidden/'), flags.includes('--drafts'));
    const index = readFileSync(join(output, 'tags/index.html'), 'utf8');
    assert.equal(index.includes('href="/tags/secret/"'), flags.includes('--drafts'));
    if (flags.includes('--drafts')) assert.ok(readFileSync(join(output, 'tags/secret/index.html'), 'utf8').includes('<li><a href="/hidden/">Hidden</a> <code>hidden</code></li>'));
  }
  for (const extra of [`${field}: Knowledge`, `${field}: [Knowledge]\nsurprise: extra`]) {
    writeFileSync(join(content, 'index.md'), `---\ntitle: Wiki\n${extra}\n---\nGuide.\n`);
    const rejected = spawnSync(process.execPath, [cli, 'check', content, '-c', config, '--collections', collections, '--format', 'json'], { encoding: 'utf8', timeout: 30_000 });
    assert.equal(rejected.status, 1);
    assert.ok(rejected.stdout.includes('"kind": "schema"'));
    assert.ok(rejected.stdout.includes(extra.includes('surprise') ? 'surprise' : field));
  }
}
console.log('Root and standalone tag metadata matches rendered badges across tag fields and rebuilds');

// Expected titles come from surviving authored pages, not from the JSON index.
for (const mode of ['root', 'standalone']) for (const indexed of [false, true]) {
  for (const collision of ['collection', 'asset', 'search', 'tag', 'redirect', ...(indexed ? ['content'] : [])]) {
    const root = mkdtempSync(join(tmpdir(), 'lattice-tag-ownership-'));
    const content = join(root, 'content'), posts = join(content, 'posts');
    const standalone = join(content, 'standalone'), templates = join(root, 'templates'), output = join(root, 'dist');
    for (const directory of [posts, standalone, templates, join(content, 'data')]) mkdirSync(directory, { recursive: true });
    const note = (title, extra = '') => `---\ntitle: ${title}\ntags: [Knowledge]\n${extra}---\n## Authored ${title}\n`;
    writeFileSync(join(posts, 'catalog.md'), note('Catalog'));
    writeFileSync(join(standalone, 'survivor.md'), note('Survivor'));
    writeFileSync(join(standalone, 'hidden.md'), note('Hidden', 'draft: true\n'));
    const slug = collision === 'collection' ? 'posts' : collision === 'tag' ? 'tags' : collision === 'asset' ? 'static' : 'masked';
    writeFileSync(join(mode === 'root' ? content : standalone, `${slug}.md`), note('Masked'));
    const asset = join(content, slug, 'index.html');
    if (collision === 'asset') { mkdirSync(join(content, slug)); writeFileSync(asset, 'Copied replacement'); }
    const sender = join(content, 'sender.md');
    if (collision === 'redirect') writeFileSync(sender, `---\ntitle: Sender\nredirect_from: [/${slug}/]\n---\nSender.\n`);
    writeFileSync(join(templates, 'page.html'), '{{content}}');
    writeFileSync(join(templates, 'index.html'), 'Generated collection {{content}}');
    writeFileSync(join(templates, 'tag.html'), '{{content}}');
    writeFileSync(join(templates, 'tags.html'), '{{content}}');
    writeFileSync(join(templates, '404.html'), '{{content}}');
    const collections = join(root, 'collections.cfg'), config = join(root, 'site.cfg');
    const configure = (masked) => {
      writeFileSync(collections, `[${collision === 'collection' && !masked ? 'other' : 'posts'}]\nschema = title:String,tags:Array[String]\ndir = ${posts}\n`);
      writeFileSync(config, `title = Ownership\nbase_url = https://example.test\npage_size = 1\ntemplates_dir = ${templates}\ncollections_file = ${collections}\noutput_dir = ${output}\n` +
        (indexed ? `content_index_file = ${collision === 'content' && masked ? `${slug}/index.html` : 'content-index.json'}\n` : '') +
        (collision === 'search' && masked ? `search_index_file = ${slug}/index.html\n` : ''));
    };
    const run = (flags = []) => {
      const result = spawnSync(process.execPath, [cli, 'build', content, '-c', config, '--collections', collections, ...flags], { encoding: 'utf8', timeout: 30_000 });
      assert.equal(result.status, 0, result.stdout + result.stderr);
      return result.stdout;
    };
    const verify = (masked, drafts) => {
      const expected = ['Catalog', ...(drafts ? ['Hidden'] : []), ...(!masked && mode === 'standalone' ? ['Masked'] : []), 'Survivor', ...(!masked && mode === 'root' ? ['Masked'] : [])];
      const titles = expected.flatMap((_, i) => {
        const path = i === 0 ? 'tags/knowledge/index.html' : `tags/knowledge/page/${i + 1}/index.html`;
        const html = readFileSync(join(output, path), 'utf8');
        assert.equal(html.includes('>Next</a>'), i + 1 < expected.length, `${mode}/${indexed}/${collision}: pagination`);
        return [...html.matchAll(/<li><a href="[^"]+">([^<]+)<\/a> <code>[^<]+<\/code><\/li>/g)].map((match) => match[1]);
      });
      assert.deepEqual(titles, expected, `${mode}/${indexed}/${collision}: surviving tag members`);
      if (collision !== 'tag' || masked) assert.ok(readFileSync(join(output, 'tags/index.html'), 'utf8').includes(`Knowledge</a> (${expected.length})`));
      const published = readFileSync(join(output, slug, 'index.html'), 'utf8');
      assert.equal(published.includes('<h2 id="authored-masked">'), !masked);
    };
    configure(true);
    for (const [round, flags] of [[], [], ['--force'], ['--drafts'], []].entries()) {
      const log = run(flags);
      if (round === 1) assert.ok(log.includes('[skip] posts/catalog'), log);
      verify(true, flags.includes('--drafts'));
    }
    // The tags index always owns /tags/; removing that collision would change routing.
    if (collision === 'tag') continue;
    if (collision === 'asset') unlinkSync(asset);
    if (collision === 'redirect') writeFileSync(sender, '---\ntitle: Sender\n---\nSender.\n');
    configure(false);
    for (const flags of [[], [], ['--force'], ['--drafts']]) { run(flags); verify(false, flags.includes('--drafts')); }
    if (mode === 'root' && !indexed && collision === 'collection') {
      for (const template of ['tag', 'tags']) {
        const before = readFileSync(join(output, 'tags/knowledge/index.html'), 'utf8');
        const original = readFileSync(join(templates, `${template}.html`), 'utf8');
        writeFileSync(join(templates, `${template}.html`), '{{unknown_required_slot}}');
        const rejected = spawnSync(process.execPath, [cli, 'build', content, '-c', config, '--collections', collections, '--force'], { encoding: 'utf8', timeout: 30_000 });
        assert.equal(rejected.status, 1, rejected.stdout + rejected.stderr);
        assert.equal(readFileSync(join(output, 'tags/knowledge/index.html'), 'utf8'), before);
        writeFileSync(join(templates, `${template}.html`), original);
      }
    }
  }
}
console.log('Tag membership follows final output ownership with and without a content index');
