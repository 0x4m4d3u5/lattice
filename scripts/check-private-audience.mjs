import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Only synthetic local files. No server, browser, external retrieval, or cleanup.
const root = mkdtempSync(join(tmpdir(), 'lattice-private-audience-'));
const content = join(root, 'content'), config = join(root, 'site.cfg');
const cli = process.env.LATTICE_NATIVE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const executable = process.env.LATTICE_NATIVE_CLI ? cli : process.execPath;
const prefix = process.env.LATTICE_NATIVE_CLI ? [] : [cli];
const put = (p, text) => { mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, text); };
const note = (title, visibility, body = 'Fixture body.', extra = '') => `---\ntitle: ${title}\n${visibility === null ? '' : `visibility: ${visibility}\n`}${extra}---\n${body}\n`;
const configText = (extra = '', allow = [], index = 'content-index.json') => `title = Private export fixture\nbase_url = http://127.0.0.1:8000\ncollections_file = ${root}/collections.cfg\ntemplates_dir = ${root}/templates\ndata_dir = ${root}/data\nstandalone_dir = ${root}/standalone\nwikilink_aliases = true\n${allow === null ? '' : `static_allowlist = ${JSON.stringify(allow)}\n`}${index === null ? '' : `content_index_file = ${index}\n`}${extra}`;
let seq = 0, output;
const next = () => output = join(root, `export-${++seq}`);
const snapshot = p => {
  if (!existsSync(p)) return null;
  if (!statSync(p).isDirectory()) return [readFileSync(p).toString('hex'), statSync(p).mtimeMs];
  return Object.fromEntries(readdirSync(p).sort().map(name => [name, snapshot(join(p, name))]));
};
const run = (command, flags = [], destination = true) => {
  const r = spawnSync(executable, [...prefix, command, content, '-c', config, ...(destination ? ['-o', output] : []), ...flags], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(r.error); return r;
};
const flags = (command, audience = 'private') => ['--audience', audience, ...(command === 'check' ? [] : ['--fresh-output']), ...(command === 'build' ? [] : ['--format', 'json'])];
const rejected = (label, extra = [], pattern = null) => {
  next();
  for (const command of ['check', 'inventory', 'build']) {
    const before = snapshot(root), r = run(command, [...flags(command), ...extra]);
    assert.equal(r.status, 1, `${label}: ${command}\n${r.stdout}${r.stderr}`);
    if (pattern) assert.match(r.stdout + r.stderr, pattern);
    if (command === 'inventory') { const report = JSON.parse(r.stdout); assert.equal(report.ready, false); assert.deepEqual(report.entries, []); }
    if (command === 'check') assert.ok(JSON.parse(r.stdout).violations.length > 0);
    assert.deepEqual(snapshot(root), before, `${label}: mutation`);
  }
};
const publish = (audience = 'private', extra = []) => {
  next(); const before = snapshot(root);
  let r = run('check', [...flags('check', audience), ...extra]); assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.deepEqual(JSON.parse(r.stdout).violations, []);
  r = run('inventory', [...flags('inventory', audience), ...extra]); assert.equal(r.status, 0, r.stdout + r.stderr);
  const report = JSON.parse(r.stdout); assert.equal(report.ready, true);
  assert.deepEqual(snapshot(root), before, 'previews must be read-only');
  r = run('build', [...flags('build', audience), ...extra]); assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.equal(existsSync(join(output, '.lattice-cache')), false);
  assert.equal(existsSync(join(output, '.lattice-manifest.json')), false);
  const files = [];
  const walk = (dir, relative = '') => { for (const name of readdirSync(dir)) { const p = join(dir, name), key = relative + name; if (statSync(p).isDirectory()) walk(p, key + '/'); else files.push(key); } };
  walk(output);
  assert.deepEqual(files.sort(), report.entries.filter(e => e.status === 'planned').map(e => e.path).sort());
  return { path: output, files, report, index: JSON.parse(readFileSync(join(output, 'content-index.json'), 'utf8')) };
};
const scan = (result, needles) => { for (const file of result.files) { const bytes = readFileSync(join(result.path, file)).toString('utf8').toLowerCase(); for (const value of needles) for (const needle of [value.toLowerCase(), value.toLowerCase().replaceAll('_', '-')]) { assert.ok(!bytes.includes(needle), `${needle} leaked in ${file}`); assert.ok(!file.toLowerCase().includes(needle)); } } };

put(config, configText());
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String,tags:Optional[Array[String]],draft:Optional[Bool],supersedes:Optional[Array[Ref[notes]]],observed_at:Optional[DateTime]\n[external]\ndir = ${root}/external\nschema = title:String\n`);
put(join(root, 'templates/page.html'), '<html><body>{{content}}{{backlinks}}{{reader_metadata}}</body></html>');
put(join(root, 'templates/404.html'), '<html><body>{{content}}</body></html>');
mkdirSync(join(root, 'data'), { recursive: true });
const privatePath = join(content, 'notes/private.md');
put(privatePath, note('PRIVATE_TITLE_CANARY', 'private', '## Evidence\nPRIVATE_BODY_CANARY café 🌱.', 'aliases: [PRIVATE_ALIAS_CANARY]\ntags: [PRIVATE_TAG_CANARY]\nobserved_at: 2026-11-01T00:00:00Z\n'));
put(join(content, 'notes/public.md'), note('Public', 'public', 'PUBLIC_BODY'));
put(join(content, 'notes/unlabelled.md'), note('UNLABELLED_TITLE_CANARY', null, 'UNLABELLED_BODY_CANARY'));
put(join(content, 'notes/draft.md'), note('PRIVATE_DRAFT_CANARY', 'private', 'PRIVATE_DRAFT_CANARY', 'draft: true\n'));
put(join(content, 'index.md'), note('Home', 'private', 'PRIVATE_ROOT_CANARY'));
put(join(root, 'standalone/about.md'), note('About', 'private', 'PRIVATE_STANDALONE_CANARY'));
put(join(root, 'external/remote.md'), note('External', 'private', 'PRIVATE_EXTERNAL_CANARY'));
put(join(content, '404.md'), note('Not found', 'private', 'PRIVATE_404_CANARY [[private#Evidence]] [private](notes/private/#evidence)'));
put(join(content, 'static/withheld.bin'), 'WITHHELD_ASSET_CANARY');
put(join(root, 'old-release/old.html'), 'STALE_RELEASE_CANARY');
put(join(root, 'old-release/.lattice-cache/cache.json'), 'STALE_RELEASE_CANARY');
const original = snapshot(content), old = snapshot(join(root, 'old-release'));

// No fallback to configured/default public dist, live modes, invalid spelling, or repeated audience.
next();
for (const command of ['build', 'inventory', 'check']) {
  let before = snapshot(root), r = run(command, flags(command), false);
  assert.equal(r.status, 1); assert.match(r.stdout + r.stderr, /explicit --output-dir/); assert.deepEqual(snapshot(root), before);
  for (const bad of [['--audience=private'], ['--audience', 'PRIVATE'], ['--audience', 'private', '--audience', 'public'], [...flags(command), '--watch']]) {
    before = snapshot(root); r = run(command, bad); assert.equal(r.status, 1, r.stdout + r.stderr); assert.deepEqual(snapshot(root), before);
  }
}
for (const command of ['serve', 'dev', 'stats', 'init']) { const before = snapshot(root), r = run(command, ['--audience', 'private']); assert.equal(r.status, 1); assert.match(r.stdout + r.stderr, /supported only by build, check and inventory/); assert.deepEqual(snapshot(root), before); }
for (const command of ['build', 'inventory']) { const r = run(command, ['--audience', 'private']); assert.equal(r.status, 1); assert.equal(existsSync(output), false); }
put(config, configText('', null)); rejected('no allowlist');
put(config, configText('', [], null)); rejected('no index');
// A private destination cannot sit in the configured publication root, even if
// that root is unused. The CLI override must not erase the original boundary.
for (const publicRoot of [join(root, 'public-unused'), join(root, 'old-release'), './relative-public', `${root}/unused/../normalized-public`]) {
  put(config, configText(`output_dir = ${publicRoot}\n`));
  for (const target of [publicRoot, join(publicRoot, 'memory'), `${publicRoot}/../${publicRoot.split('/').at(-1)}/memory`]) {
    output = target;
    for (const command of ['check', 'inventory', 'build']) {
      const before = snapshot(root), r = run(command, flags(command));
      assert.equal(r.status, 1); assert.match(r.stdout + r.stderr, /configured publication output_dir/);
      assert.deepEqual(snapshot(root), before);
    }
  }
}
put(config, configText());
for (const target of [join(root, 'dist'), join(root, 'dist/memory')]) {
  output = target;
  for (const command of ['check', 'inventory', 'build']) {
    const before = snapshot(root), r = run(command, flags(command));
    assert.equal(r.status, 1); assert.match(r.stdout + r.stderr, /configured publication output_dir/); assert.deepEqual(snapshot(root), before);
  }
}
for (const base of ['https://public.example', '//public.example', 'http://127.0.0.1.evil', 'http://127.0.0.1@evil', 'http://[::1]:65536', 'http://localhost', 'http://127.0.0.1/path']) {
  put(config, configText().replace('http://127.0.0.1:8000', base)); rejected('nonlocal base URL', [], /loopback origin/);
}
put(join(root, 'templates/index.html'), '<html><head></head><body>{{content}}</body></html>');
for (const base of ['/', 'http://[::1]:8000/', 'https://127.0.0.1:443']) {
  put(config, configText('site_feed_enabled = true\nrobots_txt = true\n').replace('http://127.0.0.1:8000', base));
  const local = publish();
  assert.ok(!local.files.some(p => /(^|\/)(feed\.(xml|json)|sitemap\.xml|robots\.txt)$/.test(p)));
  for (const file of local.files.filter(f => f.endsWith('.html'))) assert.doesNotMatch(readFileSync(join(local.path, file), 'utf8'), /application\/(rss\+xml|feed\+json)|feed\.(xml|json)/);
}
unlinkSync(join(root, 'templates/index.html'));
// Prefix siblings are allowed. An unrelated configured root does not block it.
put(config, configText(`output_dir = ${root}/export\n`));
const priv = publish();
assert.deepEqual(snapshot(content), original); assert.deepEqual(snapshot(join(root, 'old-release')), old);
for (const canary of ['PRIVATE_BODY_CANARY', 'UNLABELLED_BODY_CANARY', 'PRIVATE_ROOT_CANARY', 'PRIVATE_STANDALONE_CANARY', 'PRIVATE_EXTERNAL_CANARY']) assert.ok(JSON.stringify(priv.index).includes(canary));
assert.match(readFileSync(join(priv.path, '404.html'), 'utf8'), /PRIVATE_404_CANARY/);
scan(priv, ['PRIVATE_DRAFT_CANARY', 'WITHHELD_ASSET_CANARY', 'STALE_RELEASE_CANARY']);
const entry = priv.index.find(e => e.url === '/notes/private/');
assert.equal(entry.observed_at, '2026-11-01T00:00:00Z');
assert.equal(entry.publication.digest, createHash('sha256').update(readFileSync(join(priv.path, 'notes/private/index.html'))).digest('hex'));
assert.ok(entry.sections.some(s => s.fragment === 'evidence' && s.body.includes('PRIVATE_BODY_CANARY') && s.retention));
const privateBytes = snapshot(priv.path);
const pub = publish('public'); for (const file of ['feed.xml', 'feed.json', 'notes/feed.xml', 'notes/feed.json', 'sitemap.xml', 'robots.txt']) assert.ok(pub.files.includes(file)); scan(pub, ['PRIVATE_', 'UNLABELLED_', 'WITHHELD_ASSET_CANARY', 'STALE_RELEASE_CANARY']);
assert.deepEqual(snapshot(priv.path), privateBytes);
// Reusing either audience's root fails, including --force. No cleanup or cache reuse.
for (const audience of ['private', 'public']) for (const target of [priv.path, pub.path]) {
  output = target;
  for (const command of ['build', 'inventory', 'check']) { const before = snapshot(root), r = run(command, [...flags(command, audience), '--force']); assert.equal(r.status, 1); assert.deepEqual(snapshot(root), before); }
}
next();
for (const command of ['build', 'check', 'inventory']) { const before = snapshot(root), r = run(command, command === 'check' ? [] : ['--fresh-output']); assert.equal(r.status, 1); assert.deepEqual(snapshot(root), before); }
const drafts = publish('private', ['--drafts']); assert.ok(JSON.stringify(drafts.index).includes('PRIVATE_DRAFT_CANARY'));
// Private references and authored correction context resolve across all selected sources.
const publicPath = join(content, 'notes/public.md'), publicOriginal = readFileSync(publicPath);
put(publicPath, note('Public', 'public', '[[PRIVATE_ALIAS_CANARY#Evidence]]', 'supersedes: [private]\n'));
const cross = publish(); assert.equal(cross.index.find(e => e.url === '/notes/public/').supersedes[0].url, '/notes/private/');
next(); for (const command of ['build', 'check', 'inventory']) { const r = run(command, flags(command, 'public')); assert.equal(r.status, 1); assert.equal(existsSync(output), false); }
put(publicPath, publicOriginal);
// Visibility validation is not disabled in private mode, including hidden drafts and 404.
for (const path of [privatePath, join(content, '404.md')]) {
  const saved = readFileSync(path);
  for (const source of [note('Bad', 'false', 'CANARY', 'draft: true\n'), note('Bad', '" private "'), note('Bad', '[private]'), '---\ntitle: Bad\nvisibility: private\n"visibility": public\n---\nCANARY', '+++\ntitle = "Bad"\nvisibility = true\n+++\nCANARY', '---\nvisibility: private\nbroken line\n---\nCANARY']) { put(path, source); rejected('invalid metadata'); }
  for (const key of ['"visibility"', "'visibility'"]) { put(path, `+++\ntitle = "Quoted"\n${key} = "private"\n+++\n## Evidence\nQUOTED_PRIVATE_CANARY`); const quoted = publish(); assert.ok(quoted.files.some(file => readFileSync(join(quoted.path, file)).includes(Buffer.from('QUOTED_PRIVATE_CANARY')))); }
  put(path, saved);
}
// Private 404 is audited at its actual route; no late reread or unchecked links.
const four = join(content, '404.md'), saved404 = readFileSync(four);
for (const body of ['[[missing]]', '[missing](missing/)', '![missing](/static/missing.png)', '![[missing.png]]']) { put(four, note('Not found', 'private', body)); rejected('404 links'); }
put(four, saved404);
// Explicit selected attachments are copied whole; withheld bytes stay absent.
put(join(content, 'static/chosen.bin'), Buffer.from([0, 255, 127, 10]));
put(config, configText('', ['chosen.bin'])); const assets = publish(); assert.deepEqual(readFileSync(join(assets.path, 'static/chosen.bin')), Buffer.from([0, 255, 127, 10])); scan(assets, ['WITHHELD_ASSET_CANARY']);
for (const index of ['graph.json', '404.html', 'static/chosen.bin', 'search-index.json', 'notes/private/index.html']) { put(config, configText('', ['chosen.bin'], index)); rejected('index ownership', [], /content index collides/); }
put(config, configText());
// Missing-frontmatter remains explicit; a private audience never silently enables it.
const collectionsPath = join(root, 'collections.cfg'), savedCollections = readFileSync(collectionsPath, 'utf8');
put(collectionsPath, savedCollections.replace('schema = title:String\n', 'schema = title:Optional[String]\n'));
const bare = join(root, 'external/bare.md'); put(bare, 'BARE_PRIVATE_CANARY'); rejected('frontmatter policy');
put(config, configText('allow_missing_frontmatter = true\n')); const bareResult = publish(); assert.ok(JSON.stringify(bareResult.index).includes('BARE_PRIVATE_CANARY'));
const barePublic = publish('public'); scan(barePublic, ['PRIVATE_', 'UNLABELLED_', 'BARE_PRIVATE_CANARY']);
unlinkSync(bare); put(collectionsPath, savedCollections); put(config, configText());
// Fresh-root containment checks are unchanged for the new audience.
for (const target of [join(content, 'new-output'), join(root, 'external/new-output'), join(root, 'templates/new-output')]) { output = target; const before = snapshot(root), r = run('build', flags('build')); assert.equal(r.status, 1); assert.deepEqual(snapshot(root), before); }
assert.deepEqual(snapshot(priv.path), privateBytes); assert.deepEqual(snapshot(join(root, 'old-release')), old);
console.log('Private audience: explicit filesystem-only exports, all source kinds, independent drafts, index pairing/context, invalid metadata, 404 audits, selected assets, fresh-root/index ownership refusal and public/default canaries passed');
