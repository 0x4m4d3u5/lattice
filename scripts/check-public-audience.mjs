import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Synthetic inputs/releases only: never delete or reuse a real output directory.
// Run using the pinned Node selected by check-baseline.sh/check-targets.sh.
const root = mkdtempSync(join(tmpdir(), 'lattice-public-audience-'));
const content = join(root, 'content'), config = join(root, 'site.cfg');
const cli = process.env.LATTICE_NATIVE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const executable = process.env.LATTICE_NATIVE_CLI ? cli : process.execPath;
const prefix = process.env.LATTICE_NATIVE_CLI ? [] : [cli];
let sequence = 0, output;
const next = () => { output = join(root, `release-${++sequence}`); };
const put = (path, text) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, text); };
const note = (title, visibility = 'public', body = 'Public body.', fields = '') => `---\ntitle: ${title}\n${visibility === null ? '' : `visibility: ${visibility}\n`}${fields}---\n${body}\n`;
const configText = (allow = ['public.png'], extra = '', staticDir = 'static') => `title = Public audience fixture\nbase_url = https://example.test\ncollections_file = ${root}/collections.cfg\ntemplates_dir = ${root}/templates\ndata_dir = ${root}/data\nstandalone_dir = ${root}/standalone\ncontent_index_file = content-index.json\nwikilink_aliases = true\nstatic_dir = ${staticDir}\n${allow === null ? '' : `static_allowlist = ${JSON.stringify(allow)}\n`}${extra}`;
const snapshot = path => {
  if (!existsSync(path)) return null;
  if (!statSync(path).isDirectory()) return { file: readFileSync(path).toString('hex') };
  const files = {};
  const walk = (dir, prefix = '') => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const p = join(dir, entry.name), key = prefix + entry.name;
      if (entry.isDirectory()) { files[key + '/'] = null; walk(p, key + '/'); }
      else files[key] = [readFileSync(p).toString('hex'), statSync(p).mtimeMs];
    }
  };
  walk(path); return files;
};
const run = (command, flags = []) => {
  const r = spawnSync(executable, [...prefix, command, content, '-o', output, '-c', config, ...flags], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(r.error); return r;
};
const flagsFor = command => ['--audience', 'public', ...(command === 'check' ? [] : ['--fresh-output']), ...(command === 'build' ? [] : ['--format', 'json'])];
const ok = (command, flags = []) => {
  const r = run(command, [...flagsFor(command), ...flags]);
  assert.equal(r.status, 0, `${command}: ${r.stdout}${r.stderr}`); return r;
};
const reject = (label, flags = [], diagnostic = null) => {
  next();
  for (const command of ['build', 'inventory', 'check']) {
    const before = snapshot(root);
    const r = run(command, [...flagsFor(command), ...flags]);
    assert.equal(r.status, 1, `${label}: ${command} accepted unsafe publication\n${r.stdout}${r.stderr}`);
    if (diagnostic) assert.match(r.stdout + r.stderr, diagnostic, `${label}: missing boundary diagnostic`);
    if (command === 'inventory') {
      const report = JSON.parse(r.stdout);
      assert.equal(report.ready, false); assert.deepEqual(report.entries, []);
    }
    if (command === 'check') assert.ok(JSON.parse(r.stdout).violations.length > 0, r.stdout);
    assert.deepEqual(snapshot(root), before, `${label}: ${command} mutated inputs or prior releases`);
    assert.equal(existsSync(output), false);
  }
};
const preview = flags => {
  const before = snapshot(root);
  const check = JSON.parse(ok('check', flags).stdout);
  assert.deepEqual(check.violations, []);
  const report = JSON.parse(ok('inventory', flags).stdout);
  assert.equal(report.ready, true);
  assert.equal(report.entries.some(e => e.kind === 'build_metadata'), false);
  assert.deepEqual(snapshot(root), before, 'check/inventory changed files');
  return report;
};
const sentinels = ['EXCLUDED_BODY_', 'EXCLUDED_TITLE_', 'EXCLUDED_ALIAS_', 'EXCLUDED_TAG_', 'EXCLUDED_ROUTE_', 'EXCLUDED_PATH_', 'WITHHELD_ASSET_BYTES', 'STALE_RELEASE_BYTES', 'PUBLIC_DRAFT_BYTES'];
const scan = (dir, forbidden = sentinels) => {
  for (const [path, bytes] of Object.entries(snapshot(dir))) {
    for (const secret of forbidden) {
      // Slugs/tags can lowercase and replace underscores with hyphens.
      const needles = [secret.toLowerCase(), secret.toLowerCase().replaceAll('_', '-')];
      for (const needle of needles) {
        assert.ok(!path.toLowerCase().includes(needle), `excluded route leaked: ${path}`);
        if (bytes) assert.ok(!Buffer.from(bytes[0], 'hex').toString('utf8').toLowerCase().includes(needle), `${secret} leaked into ${path}`);
      }
    }
  }
};
const publish = (flags = [], forbidden = sentinels) => {
  next(); const report = preview(flags), before = snapshot(content), old = snapshot(join(root, 'old-release'));
  ok('build', flags);
  assert.deepEqual(snapshot(content), before, 'build mutated content');
  assert.deepEqual(snapshot(join(root, 'old-release')), old, 'build changed previous release');
  const files = Object.keys(snapshot(output)).filter(p => !p.endsWith('/')).sort();
  assert.deepEqual(files, report.entries.filter(e => e.status === 'planned').map(e => e.path).sort());
  assert.equal(existsSync(join(output, '.lattice-cache')), false);
  assert.equal(existsSync(join(output, '.lattice-manifest.json')), false);
  scan(output, forbidden); return report;
};
put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:String,tags:Optional[Array[String]],draft:Optional[Bool],related:Optional[Array[Ref[notes]]]\n[external]\ndir = ${root}/external\nschema = title:String\n`);
put(join(root, 'templates/page.html'), '<html><body>{{content}}{{reader_metadata}}{{backlinks}}{{related_notes}}</body></html>');
put(join(root, 'templates/404.html'), '<html><body>{{content}}</body></html>');
mkdirSync(join(root, 'data'), { recursive: true });
put(config, configText());
const publicSource = join(content, 'notes/source.md');
const publicBody = '## Context\nPUBLIC_BACKLINK_CONTEXT [[Destination#Evidence|proof]].';
put(publicSource, note('Source', 'public', publicBody, 'tags: [shared]\nrelated: [target]\nredirect_from: [/old-source/]\n'));
put(join(content, 'notes/target.md'), note('Target', 'public', '## Evidence\nPUBLIC_TARGET_BODY', 'aliases: [Destination]\ntags: [shared]\n'));
put(join(content, 'index.md'), note('Home', 'public', 'PUBLIC_HOME_BODY'));
put(join(root, 'standalone/about.md'), note('About', 'public', 'PUBLIC_ABOUT_BODY'));
put(join(root, 'external/outside.md'), note('Outside', 'public', 'PUBLIC_EXTERNAL_BODY'));
put(join(content, 'notes/draft.md'), note('Draft', 'public', 'PUBLIC_DRAFT_BYTES', 'draft: true\n'));
const privateSource = join(content, 'notes/EXCLUDED_PATH_private.md');
const excluded = [privateSource, join(content, 'notes/EXCLUDED_PATH_unlabelled.md'), join(root, 'standalone/EXCLUDED_PATH_standalone.md'), join(root, 'external/EXCLUDED_PATH_external.md'), join(content, 'EXCLUDED_PATH_root.md'), join(content, 'notes.md'), join(content, '404.md')];
const secretNote = (id, visibility = 'private') => note(`EXCLUDED_TITLE_${id}`, visibility, `EXCLUDED_BODY_${id} [[target]] ![[withheld.bin]] [[does-not-exist]]`, `aliases: [EXCLUDED_ALIAS_${id}]\ntags: [EXCLUDED_TAG_${id}]\nredirect_from: [/EXCLUDED_ROUTE_${id}/]\n`);
for (const [i, path] of excluded.entries()) put(path, secretNote(i, i % 2 ? null : 'private'));
put(join(content, 'notes/EXCLUDED_PATH_draft.md'), note('EXCLUDED_TITLE_draft', 'private', 'EXCLUDED_BODY_draft [[target]]', 'draft: true\n'));
const publicBytes = Buffer.from([0, 255, 128, 13, 10, 1]);
put(join(content, 'static/public.png'), publicBytes);
put(join(content, 'static/withheld.bin'), 'WITHHELD_ASSET_BYTES');
put(join(root, 'old-release/old.html'), 'STALE_RELEASE_BYTES');
put(join(root, 'old-release/.lattice-manifest.json'), 'STALE_RELEASE_BYTES');

// Reject CLI misuse before reading/writing a release. No live/repeated mode.
next();
for (const [command, flags] of [
  ['build', ['--audience', 'public']], ['inventory', ['--audience', 'public']],
  ...['build', 'inventory', 'check'].flatMap(command => [
    [command, ['--audience', 'private']], [command, ['--audience', 'PUBLIC']], [command, ['--audience']],
    [command, ['--audience=public', '--fresh-output']],
    [command, ['--audience', 'public', '--audience', 'public', '--fresh-output']],
  ]),
  ['build', ['--audience', 'public', '--fresh-output', '--watch']],
  ['check', ['--audience', 'public', '--watch']],
  ['inventory', ['--audience', 'public', '--fresh-output', '--watch']],
  ['inventory', ['--audience', 'public', '--fresh-output', '--watch=true']],
  ...['serve', 'dev', 'init', 'stats'].map(command => [command, ['--audience', 'public']]),
  ['check', ['--audience', 'public', '--fresh-output']],
]) {
  const before = snapshot(root), r = run(command, flags);
  assert.equal(r.status, 1, `${command} ${flags.join(' ')}\n${r.stdout}${r.stderr}`);
  if (['serve', 'dev', 'init', 'stats'].includes(command)) assert.match(r.stdout + r.stderr, /--audience is supported only by build, check and inventory/);
  assert.deepEqual(snapshot(root), before, 'CLI misuse changed files');
}
const beforePrefix = snapshot(root);
const prefixMisuse = spawnSync(executable, [...prefix, '--audience', 'public', 'build', content, '-o', output, '-c', config, '--fresh-output'], { cwd: root, encoding: 'utf8', timeout: 30_000 });
assert.ifError(prefixMisuse.error);
assert.equal(prefixMisuse.status, 1, prefixMisuse.stdout + prefixMisuse.stderr);
assert.deepEqual(snapshot(root), beforePrefix, 'prefix audience misuse changed files');
// Omitted audience keeps the established reject-private policy.
for (const command of ['build', 'check', 'inventory']) {
  const before = snapshot(root), r = run(command, command === 'check' ? [] : ['--fresh-output']);
  assert.equal(r.status, 1, r.stdout + r.stderr); assert.deepEqual(snapshot(root), before);
}
put(config, configText(null)); reject('missing explicit allowlist');
put(config, configText());
const report = publish();
assert.ok(report.entries.some(e => e.status === 'excluded' && JSON.stringify(e).includes('EXCLUDED_PATH_private')), 'local audit must account for private exclusion');
// Inventory is a local audit, deliberately never written into the release.
assert.deepEqual(readFileSync(join(output, 'static/public.png')), publicBytes);
for (const path of ['notes/target/index.html', 'notes/source/index.html', 'old-source/index.html', 'about/index.html', 'external/outside/index.html', '404.html', 'search-index.json', 'graph.json', 'content-index.json', 'feed.xml', 'tags/shared/index.html']) assert.ok(existsSync(join(output, path)), path);
const targetHtml = readFileSync(join(output, 'notes/target/index.html'), 'utf8');
assert.match(targetHtml, /PUBLIC_BACKLINK_CONTEXT/);
assert.match(targetHtml, /Backlinks \(1\)/);
const graph = JSON.parse(readFileSync(join(output, 'graph.json'), 'utf8'));
assert.deepEqual(graph.edges.map(e => [e.source, e.target]), [['source', 'target']]);
assert.equal(existsSync(join(output, 'static/withheld.bin')), false);
assert.equal(existsSync(join(output, 'notes/draft/index.html')), false);
// Existing release, empty directory and file are all forbidden targets.
for (const name of [output, join(root, 'old-release'), join(root, 'empty-output'), join(root, 'output-file')]) {
  output = name;
  if (name.endsWith('empty-output')) mkdirSync(name);
  if (name.endsWith('output-file')) put(name, 'Existing file');
  for (const command of ['build', 'check', 'inventory']) {
    const before = snapshot(root), r = run(command, [...flagsFor(command), ...(command === 'build' ? ['--force'] : [])]);
    assert.equal(r.status, 1, r.stdout + r.stderr); assert.deepEqual(snapshot(root), before);
  }
}
publish(['--drafts'], sentinels.filter(s => s !== 'PUBLIC_DRAFT_BYTES'));
assert.match(readFileSync(join(output, 'notes/draft/index.html'), 'utf8'), /PUBLIC_DRAFT_BYTES/);
put(config, configText([])); publish(); assert.equal(existsSync(join(output, 'static')), false);
// Explicit allowlisting is consent even for an attachment used only privately.
put(config, configText(['withheld.bin'])); publish([], sentinels.filter(s => s !== 'WITHHELD_ASSET_BYTES'));
assert.equal(readFileSync(join(output, 'static/withheld.bin'), 'utf8'), 'WITHHELD_ASSET_BYTES');
put(config, configText());

// Metadata errors fail closed even on otherwise excluded candidates and 404s.
for (const path of excluded) {
  const original = readFileSync(path, 'utf8');
  for (const fields of ['visibility: true\n', 'visibility: [public]\n', 'visibility: PUBLIC\n', 'visibility: ""\n', 'visibility: private\nvisibility: public\n', 'visibility: private\n"visibility": private\n']) {
    put(path, `---\ntitle: Invalid\n${fields}---\nEXCLUDED_BODY_invalid\n`); reject(`${path}: ${fields}`);
  }
  put(path, '---\nvisibility: private\ntitle without separator\n---\nEXCLUDED_BODY_invalid\n'); reject('malformed excluded frontmatter');
  put(path, original);
}
for (const value of ['false', '1', '1.5', '2026-11-07', '["public"]', '"unlisted"', '" public "']) {
  put(privateSource, `+++\ntitle = "Invalid"\nvisibility = ${value}\n+++\nEXCLUDED_BODY_invalid\n`); reject(`typed TOML ${value}`);
}
put(privateSource, '+++\ntitle = "Invalid"\nvisibility = "private"\n"visibility" = "public"\n+++\nEXCLUDED_BODY_invalid\n'); reject('duplicate TOML');
put(privateSource, secretNote(0));

// Public references to excluded Markdown never succeed through alias/fragment,
// Markdown syntax, or an unrelated writer claiming the same output path.
const publicOriginal = readFileSync(publicSource, 'utf8');
for (const body of ['[[EXCLUDED_PATH_private]]', '[[EXCLUDED_ALIAS_0#Evidence|label]]', '[private](EXCLUDED_PATH_private.md)', '[private](/notes/excluded-path-private/)', '![private](/static/withheld.bin)', '![[withheld.bin]]']) {
  put(publicSource, note('Source', 'public', body)); reject(body);
}
put(publicSource, publicOriginal);
for (const owner of ['static', 'redirect', 'generated']) {
  put(publicSource, publicOriginal);
  const victim = owner === 'generated' ? join(content, 'notes.md') : privateSource;
  const url = owner === 'generated' ? '/notes/' : '/notes/excluded-path-private/';
  if (owner === 'static') {
    put(join(content, 'notes/excluded-path-private/index.html'), 'Public static replacement');
    put(config, configText(['excluded-path-private/index.html'], '', 'notes'));
  }
  if (owner === 'redirect') put(join(content, 'notes/redirector.md'), note('Redirector', 'public', 'Public redirect body.', `redirect_from: [${url}]\n`));
  // Prove the canonical private destination really has a planned replacement.
  next();
  const collisionPlan = preview([]);
  assert.ok(collisionPlan.entries.some(e => e.status === 'planned' && e.path === url.slice(1) + 'index.html'), `${owner}: missing canonical collision owner`);
  // .md source paths also reject, but are not evidence of a route collision:
  // ordinary site routing does not resolve source filenames to output URLs.
  for (const body of [`[excluded](${url})`, `[excluded](${owner === 'generated' ? '../notes.md' : 'EXCLUDED_PATH_private.md'})`, `[[${owner === 'generated' ? 'notes' : 'EXCLUDED_PATH_private'}]]`]) {
    put(publicSource, note('Source', 'public', body)); reject(`${owner} collision: ${victim}: ${body}`, [], body.includes('.md') ? null : /public audience boundary/);
  }
  put(config, configText());
  if (owner === 'redirect') unlinkSync(join(content, 'notes/redirector.md'));
  if (owner === 'static') unlinkSync(join(content, 'notes/excluded-path-private/index.html'));
}
put(publicSource, publicOriginal);

// Explicitly copying a Markdown source is publication consent for those bytes,
// but cannot make a public parsed reference to its excluded identity acceptable.
put(config, configText(['EXCLUDED_PATH_private.md'], '', 'notes'));
next();
assert.ok(preview([]).entries.some(e => e.status === 'planned' && e.path === 'notes/EXCLUDED_PATH_private.md'));
put(publicSource, note('Source', 'public', '[source-facing private](/notes/EXCLUDED_PATH_private.md)'));
reject('allowlisted source-facing Markdown collision', [], /public audience boundary/);
put(publicSource, publicOriginal); put(config, configText());

// A public alias cannot launder an excluded name into a typed reference.
const targetSource = join(content, 'notes/target.md');
const targetOriginal = readFileSync(targetSource, 'utf8');
put(targetSource, note('Target', 'public', '## Evidence\nPUBLIC_TARGET_BODY', 'aliases: [Destination, EXCLUDED_PATH_private, EXCLUDED_ALIAS_0]\ntags: [shared]\n'));
next(); preview([]); // Public alias declarations themselves are valid.
for (const target of ['excluded-path-private', 'excluded-alias-0']) {
  put(publicSource, note('Source', 'public', 'Public typed reference.', `related: [${target}]\n`));
  // Ref[notes] accepts canonical slugs, not aliases, so schema rejection
  // alone is sufficient for these alias-only attempts.
  reject(`typed related alias shadow ${target}`);
}
put(targetSource, targetOriginal);
put(privateSource, note('Private canonical collision', 'private', 'EXCLUDED_BODY_typed', 'aliases: [target]\n'));
put(publicSource, note('Source', 'public', 'Public typed-reference control.'));
next(); preview([]); // The selected canonical target exists without the reference.
put(publicSource, note('Source', 'public', 'Public typed-reference collision.', 'related: [target]\n'));
reject('typed related canonical target shadows excluded alias', [], /public audience boundary/);
put(privateSource, secretNote(0));
put(publicSource, publicOriginal);

// Directory routes ending in .html/.htm are distinct from exact file redirects.
// An unrelated public static or redirect owner must not erase either denial.
for (const extension of ['html', 'htm']) {
  const privateFile = join(content, `notes/collision.${extension}.md`);
  put(privateFile, secretNote(`extension-${extension}`));
  const canonical = `/notes/collision.${extension}/`;
  for (const owner of ['static', 'redirect']) {
    const copiedPath = `notes/collision.${extension}/index.html`;
    if (owner === 'static') {
      put(join(content, copiedPath), 'Public static collision replacement');
      put(config, configText([copiedPath], '', '.'));
    } else put(join(content, 'notes/redirector.md'), note('Redirector', 'public', 'Public redirect replacement.', `redirect_from: [${canonical}]\n`));
    next();
    assert.ok(preview([]).entries.some(e => e.status === 'planned' && e.path === copiedPath));
    for (const url of [canonical, canonical + 'index.html']) {
      put(publicSource, note('Source', 'public', `[private directory](${url})`));
      reject(`${owner} ${extension} directory collision ${url}`, [], /public audience boundary/);
    }
    put(publicSource, publicOriginal); put(config, configText());
    if (owner === 'static') unlinkSync(join(content, copiedPath));
    else unlinkSync(join(content, 'notes/redirector.md'));
  }
  unlinkSync(privateFile);
}
put(privateSource, note('Private redirect', 'private', 'EXCLUDED_BODY_redirect', 'redirect_from: [/old.htm]\n'));
for (const owner of ['static', 'redirect']) {
  if (owner === 'static') {
    put(join(content, 'old.htm'), 'Public static exact-file replacement');
    put(config, configText(['old.htm'], '', '.'));
  } else put(join(content, 'notes/redirector.md'), note('Redirector', 'public', 'Public exact-file redirect.', 'redirect_from: [/old.htm]\n'));
  next();
  const ownerPath = owner === 'static' ? 'old.htm' : 'old.htm/index.html';
  assert.ok(preview([]).entries.some(e => e.status === 'planned' && e.path === ownerPath), `${owner}: missing old.htm owner`);
  put(publicSource, note('Source', 'public', '[private exact redirect](/old.htm)'));
  reject(`${owner} private exact-file redirect collision`, [], /public audience boundary/);
  put(publicSource, publicOriginal); put(config, configText());
  if (owner === 'static') unlinkSync(join(content, 'old.htm'));
  else unlinkSync(join(content, 'notes/redirector.md'));
}
put(privateSource, secretNote(0));

// The reference gate covers every authored public source, not just collections.
for (const path of [join(content, 'index.md'), join(root, 'standalone/about.md'), join(root, 'external/outside.md'), join(content, 'notes.md')]) {
  const original = readFileSync(path, 'utf8');
  for (const body of ['[[EXCLUDED_ALIAS_0#Evidence|label]]', '[private](/notes/excluded-path-private/)']) {
    put(path, note('Public referrer', 'public', body)); reject(`public source ${path}: ${body}`);
  }
  put(path, original);
}

// A public 404 must pass the same parsed reference checks. Excluded 404s use a
// fallback and do not validate or render their broken private links/embeds.
for (const body of ['[[missing]]', '![[missing.png]]', '[private](/notes/excluded-path-private/)']) {
  put(join(content, '404.md'), note('Not found', 'public', body)); reject('public 404 ' + body);
}
put(join(content, '404.md'), note('Not found', 'public', 'PUBLIC_404_BODY [[target]]'));
publish();
const public404 = readFileSync(join(output, '404.html'), 'utf8');
assert.match(public404, /PUBLIC_404_BODY/);
assert.match(public404, /href="\/notes\/target\/"/);
for (const visibility of ['private', null]) {
  put(join(content, '404.md'), secretNote('404', visibility)); publish();
}
// Excluded roots must not shadow an explicitly public root-page selection.
// Remove public references first: selecting a public owner does not waive the
// separate fail-closed policy for an explicitly named excluded identity.
put(publicSource, note('Source', 'public', 'Public collision control.'));
put(join(content, 'index.md'), secretNote('home'));
put(join(content, 'target.md'), secretNote('slug-collision'));
put(join(content, 'notes/collision.md'), secretNote('collection-collision'));
put(join(content, 'collision.md'), note('Public root collision', 'public', 'PUBLIC_ROOT_COLLISION_BODY'));
put(config, configText(['public.png'], 'root_page = target\n'));
publish(); assert.match(readFileSync(join(output, 'index.html'), 'utf8'), /PUBLIC_TARGET_BODY/);
assert.match(readFileSync(join(output, 'collision/index.html'), 'utf8'), /PUBLIC_ROOT_COLLISION_BODY/);
assert.equal(existsSync(join(output, 'notes/collision/index.html')), false);
// A collection at content root must not rediscover its own files as root
// pages. Identity is normalized source path, never a global slug suppression.
for (const explicit of [false, true]) {
  const fixture = join(root, explicit ? 'root-collection-alias' : 'root-default-collection');
  const sources = join(fixture, 'content'), destination = join(fixture, 'release');
  const site = join(fixture, 'site.cfg'), collections = join(fixture, 'collections.cfg');
  const selected = join(sources, 'selected.md'), hidden = join(sources, 'EXCLUDED_PATH_same_file.md');
  put(selected, note('Selected once', 'public', 'PUBLIC_SINGLE_SOURCE_BODY', 'date: 2026-01-02\n'));
  put(hidden, note('EXCLUDED_TITLE_same_file', 'private', 'EXCLUDED_BODY_same_file', 'date: 2026-01-02\n'));
  put(join(fixture, 'templates/page.html'), '{{content}}');
  mkdirSync(join(fixture, 'data'), { recursive: true });
  put(site, `title = Source identity fixture\nbase_url = https://example.test\nstatic_allowlist = []\ntemplates_dir = ${fixture}/templates\ndata_dir = ${fixture}/data\n${explicit ? `collections_file = ${collections}\n` : ''}`);
  if (explicit) put(collections, `[posts]\ndir = ${sources}/../content/.\nschema = title:String,date:Date\n`);
  else assert.equal(existsSync(collections), false, 'default collection control must have no collection config');
  const invoke = command => {
    const r = spawnSync(executable, [...prefix, command, sources, '-o', destination, '-c', site, ...flagsFor(command)], { cwd: fixture, encoding: 'utf8', timeout: 30_000 });
    assert.ifError(r.error); assert.equal(r.status, 0, `${explicit ? 'aliased root collection' : 'default collection'} ${command}: ${r.stdout}${r.stderr}`); return r;
  };
  const before = snapshot(fixture), sourceBefore = snapshot(sources);
  assert.deepEqual(JSON.parse(invoke('check').stdout).violations, []);
  const inventory = JSON.parse(invoke('inventory').stdout);
  assert.equal(inventory.ready, true);
  const entriesFor = source => inventory.entries.filter(e => e.source && resolve(fixture, e.source) === source);
  const selectedEntries = entriesFor(selected).filter(e => e.status === 'planned');
  assert.equal(selectedEntries.length, 1, 'selected source must have one planned page owner');
  assert.equal(selectedEntries[0].path, 'posts/selected/index.html');
  assert.equal(entriesFor(hidden).filter(e => e.status === 'excluded').length, 1, 'same excluded source must be audited exactly once');
  assert.deepEqual(snapshot(fixture), before, 'dedup check/inventory mutated input or output');
  invoke('build');
  assert.deepEqual(snapshot(sources), sourceBefore, 'dedup build mutated sources');
  assert.match(readFileSync(join(destination, 'posts/selected/index.html'), 'utf8'), /PUBLIC_SINGLE_SOURCE_BODY/);
  assert.equal(existsSync(join(destination, 'selected/index.html')), false, 'collection source was rediscovered as root page');
  assert.deepEqual(Object.keys(snapshot(destination)).filter(p => !p.endsWith('/')).sort(), inventory.entries.filter(e => e.status === 'planned').map(e => e.path).sort());
  scan(destination);
}
console.log('Public audience: mixed-source sentinel isolation, derivations, fresh/static requirements, CLI misuse, typed metadata, draft policy, reference collisions, 404 and read-only preview parity passed');
