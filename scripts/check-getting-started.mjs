import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync, spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { once } from 'node:events';

// Execute the actual guide snippets, not a second handwritten starter fixture.
const guide = readFileSync(new URL('../docs/getting-started.md', import.meta.url), 'utf8');
const section = (number) => guide.split(`## ${number}. `)[1]?.split('\n## ')[0];
const blocks = (text, language) => [...text.matchAll(new RegExp('```' + language + '\\n([\\s\\S]*?)```', 'g'))].map(match => match[1]);
const namedBlock = (path, language) => {
  const text = guide.split('`' + path + '`')[1];
  assert.ok(text, `missing documented file ${path}`);
  return blocks(text, language)[0];
};
const root = mkdtempSync(join(tmpdir(), 'lattice-getting-started-'));
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const write = (path, contents) => {
  assert.equal(typeof contents, 'string', `missing snippet for ${path}`);
  mkdirSync(dirname(join(root, path)), { recursive: true });
  writeFileSync(join(root, path), contents);
};
const run = (args) => {
  const result = spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${args.join(' ')}\n${result.stdout}${result.stderr}`);
};
const pageUrl = '/posts/welcome-lattice/';
const verifyPublication = () => {
  const html = readFileSync(join(root, 'dist', pageUrl, 'index.html'), 'utf8');
  assert.ok(html.includes('Welcome to the Example Site'));
  assert.ok(html.includes('<h1 id="welcome">Welcome</h1>'));
  assert.ok(html.includes('This demo site exists to exercise the full lattice pipeline in one place.'));
  assert.ok(html.includes('Structural integrity demo') && html.includes('Built with typed content contracts'));
  for (const path of ['posts/index.html', 'posts/feed.xml', 'tags/intro/index.html', 'graph.json', 'sitemap.xml', 'robots.txt']) {
    assert.ok(existsSync(join(root, 'dist', path)), `missing documented output ${path}`);
  }
  const search = JSON.parse(readFileSync(join(root, 'dist/search-index.json'), 'utf8'));
  assert.ok(search.some(entry => entry.url === pageUrl && entry.title === 'Welcome to the Example Site'));
};
try {
  write('lattice.toml', blocks(section(1), 'cfg').at(-1));
  write('collections.cfg', blocks(section(2), 'cfg').at(-1));
  write('data/nav.toml', namedBlock('data/nav.toml', 'toml'));
  write('data/site.toml', namedBlock('data/site.toml', 'toml'));
  write('content/posts/welcome-lattice.md', blocks(section(4), 'md')[0]);
  write('templates/page.html', namedBlock('templates/page.html', 'html'));
  write('templates/index.html', namedBlock('templates/index.html', 'html'));
  const preview = blocks(guide.split('## Rebuild while editing')[1], 'sh')[0];
  assert.ok(preview.includes('--config ./lattice.toml'), 'preview must use the config created by this guide');
  run(['check', '--config', './lattice.toml']);
  assert.ok(!existsSync(join(root, 'dist')), 'check must not publish');
  // The first command is the separate repository example; execute both new-site commands.
  const commands = blocks(section(6), 'bash').slice(1);
  assert.equal(commands.length, 2);
  for (const [index, command] of commands.entries()) {
    if (index === 1) {
      // This command is documented for sites without collections_file.
      write('lattice.toml', blocks(section(1), 'cfg').at(-1)
        .replace(/^collections_file\s*=.*$/gm, ''));
    }
    // Each command must independently publish, without previous output or cache.
    rmSync(join(root, 'dist'), { recursive: true, force: true });
    assert.ok(command.startsWith('node "$LATTICE_CLI" '), 'expected documented source CLI');
    const tokens = command.trim().slice('node "$LATTICE_CLI" '.length).split(/\s+/);
    run(tokens);
    verifyPublication();
  }
  // Exercise the optional retrieval output described in the guide.
  const option = guide.match(/`(content_index_file = content-index\.json)`/);
  assert.ok(option, 'missing documented content-index opt-in');
  write('lattice.toml', blocks(section(1), 'cfg').at(-1) + '\n' + option[1] + '\n');
  run(['build', '--config', './lattice.toml']);
  const index = JSON.parse(readFileSync(join(root, 'dist/content-index.json'), 'utf8'));
  const citation = index.find(entry => entry.url === pageUrl);
  assert.ok(citation?.body.includes('exercise the full lattice pipeline'));
  assert.deepEqual(citation.tags, ['intro', 'lattice', 'demo']);
  assert.ok(existsSync(join(root, 'dist', citation.url, 'index.html')));
  // Execute the documented preview with its custom config, not just a build fixture.
  const reserve = createServer();
  reserve.listen(0, '127.0.0.1'); await once(reserve, 'listening');
  const port = reserve.address().port;
  await new Promise(resolve => reserve.close(resolve));
  const previewArgs = preview.trim().slice('node "$LATTICE_CLI" '.length).split(/\s+/);
  const child = spawn(process.execPath, [cli, ...previewArgs, '--port', String(port)], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  let diagnostics = ''; child.stdout.on('data', b => diagnostics += b); child.stderr.on('data', b => diagnostics += b);
  try {
    let served = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      assert.equal(child.exitCode, null, diagnostics);
      try {
        const response = await fetch(`http://127.0.0.1:${port}${pageUrl}`, { signal: AbortSignal.timeout(1000) });
        if (response.ok && (await response.text()).includes('Welcome to the Example Site')) { served = true; break; }
      } catch { /* Wait for the preview to bind. */ }
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    assert.ok(served, `documented preview did not serve the guide site: ${diagnostics}`);
  } finally {
    if (child.exitCode === null && child.signalCode === null) {
      const exited = once(child, 'exit');
      child.kill('SIGTERM'); await exited;
    }
  }
  console.log('Copied getting-started files, CLI commands, check/build, templates, indexes and retrieval citation passed');
} finally {
  rmSync(root, { recursive: true, force: true });
}
