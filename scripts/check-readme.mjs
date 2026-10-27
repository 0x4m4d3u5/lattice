import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const readme = readFileSync(new URL('../README.md', import.meta.url), 'utf8');
const section = heading => readme.split(`### ${heading}\n`)[1]?.split('\n##')[0];
const blocks = (text, language) => [...text.matchAll(new RegExp('```' + language + '\n([\\s\\S]*?)```', 'g'))].map(match => match[1]);
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const root = mkdtempSync(join(tmpdir(), 'lattice-readme-'));
const site = join(root, 'my-site');
const run = (command, cwd) => {
  const result = spawnSync('bash', ['-euc', command], {
    cwd, env: { ...process.env, LATTICE_CLI: cli }, encoding: 'utf8', timeout: 30_000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${command}\n${result.stdout}${result.stderr}`);
  return result.stdout;
};
try {
  // Run the documented init/cd commands outside the repository to ensure the
  // absolute CLI path works without a Moon module in the new site.
  mkdirSync(join(root, 'checkout'));
  run(blocks(section('Scaffold a new site'), 'bash')[0] + '\ntest "$PWD" = "' + site + '"', join(root, 'checkout'));
  const commands = blocks(section('Create and publish a new post'), 'bash');
  run(commands[0], site);
  const source = blocks(section('Frontmatter'), 'markdown')[0];
  writeFileSync(join(site, 'content/posts/my-first-post.md'), source);
  const check = JSON.parse(run('node "$LATTICE_CLI" check --format json', site));
  assert.deepEqual(check.violations, []);
  assert.equal(existsSync(join(site, 'dist')), false, 'check must not publish');
  run(commands[1], site);
  const html = readFileSync(join(site, 'dist/posts/my-first-post/index.html'), 'utf8');
  assert.ok(html.includes('My First Post'));
  assert.ok(html.includes('<h1 id="hello-world">Hello World</h1>'));
  assert.ok(html.includes('href="/posts/welcome/"'), 'copied wikilink must resolve');
  const search = JSON.parse(readFileSync(join(site, 'dist/search-index.json'), 'utf8'));
  assert.ok(search.some(entry => entry.url === '/posts/my-first-post/' && entry.title === 'My First Post'));
  // A bad link must stop the documented check && build chain, preserving output.
  writeFileSync(join(site, 'content/posts/my-first-post.md'), source + '\n[[missing-readme-note]]\n');
  const rejected = spawnSync('bash', ['-euc', commands[1]], {
    cwd: site, env: { ...process.env, LATTICE_CLI: cli }, encoding: 'utf8', timeout: 30_000,
  });
  assert.ifError(rejected.error);
  assert.equal(rejected.status, 1);
  assert.equal(readFileSync(join(site, 'dist/posts/my-first-post/index.html'), 'utf8'), html);
  console.log('README: copied init/new/frontmatter/check/build, resolved link, search entry and strict publication gate passed');
} finally {
  rmSync(root, { recursive: true, force: true });
}
