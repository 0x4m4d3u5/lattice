import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
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
    // Tag navigation still lists collection members, not standalone/root pages.
    assert.ok(!readFileSync(join(output, 'tags/knowledge/index.html'), 'utf8').includes('href="/manual/"'));
  };
  run('check', ['--format', 'json']);
  run('build'); verify();
  assert.ok(run('build').includes('[skip] posts/catalog')); verify();
  run('build', ['--force']); verify();
  writeFileSync(join(standalone, 'manual.md'), tagged('Manual', '[Knowledge]'));
  run('build'); verify(['Knowledge']);
  run('build', ['--force']); verify(['Knowledge']);
  for (const extra of [`${field}: Knowledge`, `${field}: [Knowledge]\nsurprise: extra`]) {
    writeFileSync(join(content, 'index.md'), `---\ntitle: Wiki\n${extra}\n---\nGuide.\n`);
    const rejected = spawnSync(process.execPath, [cli, 'check', content, '-c', config, '--collections', collections, '--format', 'json'], { encoding: 'utf8', timeout: 30_000 });
    assert.equal(rejected.status, 1);
    assert.ok(rejected.stdout.includes('"kind": "schema"'));
    assert.ok(rejected.stdout.includes(extra.includes('surprise') ? 'surprise' : field));
  }
}
console.log('Root and standalone tag metadata matches rendered badges across tag fields and rebuilds');
