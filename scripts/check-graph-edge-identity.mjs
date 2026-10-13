import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'lattice-graph-edge-identity-'));
const content = join(root, 'content');
const posts = join(content, 'posts');
const output = join(root, 'dist');
mkdirSync(posts, { recursive: true });
mkdirSync(join(content, 'standalone'));
mkdirSync(join(content, 'data'));
// These are two distinct authored relationships, even though joining each
// pair with a colon produces the same string. Repeated links remain one edge.
for (const [slug, body] of [
  ['a', 'Read [[b:c]] and [[B:C.MD|again]].'],
  ['a:b', 'Read [[c]] and [[C.MD#Heading|again]].'],
  ['b:c', '## Heading\nTarget one.'],
  ['c', '## Heading\nTarget two.'],
]) {
  writeFileSync(join(posts, `${slug}.md`), `---\ntitle: ${slug}\ndate: 2026-01-02\n---\n${body}\n`);
}
const collections = join(root, 'collections.cfg');
writeFileSync(collections, `[posts]\nschema = title:String,date:Date\ndir = ${posts}\n`);
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Graph Identity\nbase_url = https://example.test\ncollections_file = ${collections}\noutput_dir = ${output}\n`);
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const run = (command, flags = []) => {
  const result = spawnSync(process.execPath,
    [cli, command, content, '-c', config, '--collections', collections, ...flags],
    { encoding: 'utf8', timeout: 30_000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result.stdout;
};
run('check');
for (const [pass, flags] of [[], [], ['--force']].entries()) {
  const log = run('build', flags);
  if (pass === 1) assert.ok(log.includes('[4 unchanged]'), log);
  const graph = JSON.parse(readFileSync(join(output, 'graph.json'), 'utf8'));
  for (const slug of ['a', 'a:b', 'b:c', 'c']) {
    assert.ok(graph.nodes.some((node) => node.slug === slug && node.url === `/posts/${slug}/`));
  }
  assert.ok(readFileSync(join(output, 'posts/a/index.html'), 'utf8').includes('href="/posts/b:c/"'));
  assert.ok(readFileSync(join(output, 'posts/a:b/index.html'), 'utf8').includes('href="/posts/c/#heading"'));
  assert.deepEqual(graph.edges.map(({ source, target }) => [source, target]).sort(),
    [['a', 'b:c'], ['a:b', 'c']].sort());
}
console.log('Distinct colon-containing graph edges survive fresh, cached and forced publishing');
