import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Entirely synthetic fixtures; never discover or rewrite an author's vault.
const root = mkdtempSync(join(tmpdir(), 'lattice-optional-frontmatter-'));
const content = join(root, 'content'), config = join(root, 'site.cfg');
const native = process.env.LATTICE_NATIVE_CLI;
const cli = native ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
let output = join(root, 'dist'), sequence = 0;
const next = () => { output = join(root, `release-${++sequence}`); };
const put = (path, bytes) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, bytes); };
const snapshot = path => {
  if (!existsSync(path)) return null;
  const files = {};
  const walk = (dir, prefix = '') => {
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      const p = join(dir, e.name), name = prefix + e.name;
      if (e.isDirectory()) { files[name + '/'] = null; walk(p, name + '/'); }
      else files[name] = [readFileSync(p).toString('hex'), statSync(p).mtimeMs];
    }
  };
  walk(path); return files;
};
const configure = (setting = 'allow_missing_frontmatter = true\n', extra = '') => put(config,
  `title = Optional frontmatter fixture\nbase_url = https://example.test\ncollections_file = ${root}/collections.cfg\ntemplates_dir = ${root}/templates\ndata_dir = ${root}/data\nstandalone_dir = ${root}/standalone\ncontent_index_file = content-index.json\nstatic_allowlist = ["pixel.png"]\nwikilink_aliases = true\n${setting}${extra}`);
const schema = (type = 'Optional[String]') => put(join(root, 'collections.cfg'), `[notes]\ndir = ${content}/notes\nschema = title:${type},tags:Optional[Array[String]],related:Optional[Array[Ref[notes]]]\n[external]\ndir = ${root}/external\nschema = title:${type}\n`);
const note = (body, fields = 'title: Public\nvisibility: public\n') => `---\n${fields}---\n${body}\n`;
const run = (command, flags = []) => {
  const r = spawnSync(native ? cli : process.execPath, [...(native ? [] : [cli]), command, content, '-o', output, '-c', config, ...flags], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(r.error); return r;
};
const invoke = (command, flags = [], status = 0) => {
  const before = snapshot(root), r = run(command, flags);
  assert.equal(r.status, status, `${command} ${flags.join(' ')}\n${r.stdout}${r.stderr}`);
  if (command !== 'build' || status !== 0) assert.deepEqual(snapshot(root), before, `${command} mutated sources or existing releases`);
  return r;
};
const check = (kind = null, flags = [], line = null) => {
  const result = JSON.parse(invoke('check', ['--format', 'json', ...flags], kind ? 1 : 0).stdout);
  if (!kind) assert.deepEqual(result.violations, []);
  else {
    assert.ok(result.violations.some(v => v.kind === kind), JSON.stringify(result));
    if (line !== null) assert.equal(result.violations.find(v => v.kind === kind).line, line);
  }
  return result;
};
const reject = (kind, flags = [], buildFlags = flags) => {
  check(kind, flags);
  const report = JSON.parse(invoke('inventory', ['--format', 'json', ...buildFlags], 1).stdout);
  assert.equal(report.ready, false); assert.deepEqual(report.entries, []);
  invoke('build', buildFlags, 1);
};
const publish = (flags = []) => {
  const sourceBefore = snapshot(content), externalBefore = snapshot(join(root, 'external'));
  const report = JSON.parse(invoke('inventory', ['--format', 'json', ...flags]).stdout);
  assert.equal(report.ready, true);
  invoke('build', flags);
  assert.deepEqual(snapshot(content), sourceBefore);
  assert.deepEqual(snapshot(join(root, 'external')), externalBefore);
  assert.deepEqual(Object.keys(snapshot(output)).filter(p => !p.endsWith('/')).sort(), report.entries.filter(e => e.status === 'planned').map(e => e.path).sort());
  return report;
};
put(join(root, 'templates/page.html'), '<html><body>{{content}}{{backlinks}}{{related_notes}}</body></html>');
put(join(root, 'templates/404.html'), '<html><body>{{content}}</body></html>');
for (const name of ['data', 'external', 'standalone']) mkdirSync(join(root, name));
put(join(content, 'static/pixel.png'), Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jS1sAAAAASUVORK5CYII=', 'base64'));
const source = join(content, 'notes/body.md');
const body = '# Body heading\n\nBODY_ONLY_CANARY\n';
schema(); put(source, body);
for (const setting of ['', 'allow_missing_frontmatter = false\n']) {
  configure(setting); reject('frontmatter'); assert.equal(existsSync(output), false);
}
configure(); check(); publish();
assert.match(readFileSync(join(output, 'notes/body/index.html'), 'utf8'), /BODY_ONLY_CANARY/);
// Warm metadata cannot bypass a config transition back to strict parsing.
configure('allow_missing_frontmatter = false\n'); reject('frontmatter');
configure(); check(); invoke('build'); invoke('build', ['--force']);
// Existing typed boolean convention: aliases and last declaration wins.
for (const value of ['yes', '1', 'on']) { configure(`allow_missing_frontmatter = ${value}\n`); check(); }
for (const value of ['maybe', '[]']) { configure(`allow_missing_frontmatter = ${value}\n`); reject('config'); }
configure('allow_missing_frontmatter = true\nallow_missing_frontmatter = false\n'); reject('frontmatter');
configure('allow_missing_frontmatter = false\nallow_missing_frontmatter = true\n'); check();
configure();
// Header absence equals empty metadata, never a synthesized schema title.
for (const text of [body, '', '---\n---\n' + body, '+++\n+++\n' + body]) {
  put(source, text); schema(); check(); next(); publish();
  schema('String'); reject('missing_required_field');
}
schema(); put(source, body);
for (const path of [join(content, 'index.md'), join(root, 'standalone/about.md')]) {
  for (const text of [body, '---\n---\n' + body]) { put(path, text); reject('missing_required_field'); }
  unlinkSync(path);
}
// Recognized openers never fall back to Markdown after a parse failure.
for (const text of ['---\ntitle: Missing close\n', '+++\ntitle = "Missing close"\n', '---\nnot a mapping\n---\n', '+++\ntitle = [\n+++\n', '\uFEFF---\r\ntitle: Missing close\r\n', '---bad\n']) {
  put(source, text); reject('frontmatter');
}
for (const [text, line] of [
  ['[[absent]]\n', 1], ['\n\n[[absent]]\n', 3], ['\uFEFFParagraph\r\n\r\n[[absent]]\r\n', 3],
  ['---\n---\n[[absent]]\n', 3], ['\uFEFF---\r\n---\r\n[[absent]]\r\n', 3], ['+++\r\n+++\r\n[[absent]]\r\n', 3],
]) { put(source, text); check('broken_wikilink', [], line); invoke('build', ['--strict-wikilinks'], 1); }
for (const [text, kind, checkFlags, buildFlags] of [
  ['\n[Missing](/missing/)\n', 'broken_local_link', ['--local-links'], ['--strict-local-links']],
  ['\n![[missing.png]]\n', 'broken_wikilink', [], []],
  ['\n{{< unknown_fixture >}}\n', 'shortcode', [], []],
]) { put(source, text); check(kind, checkFlags, kind === 'shortcode' ? null : 2); invoke('build', buildFlags, 1); }
// Positive controls ensure real destinations exist and rendering is nonvacuous.
put(join(content, 'notes/target.md'), note('## Evidence\nPUBLIC_TARGET', 'title: Target\nvisibility: public\naliases: [Destination]\ntags: [shared]\n'));
put(source, '[[Destination#Evidence]]\n![[pixel.png]]\n[Target](/notes/target/#evidence)\n{{< image src="/static/pixel.png" alt="Pixel" >}}\n');
check(null, ['--local-links']); next(); publish(['--strict-wikilinks', '--strict-local-links']);
assert.match(readFileSync(join(output, 'notes/body/index.html'), 'utf8'), /\/static\/pixel.png/);
put(join(root, 'external/outside.md'), body); check();
// Custom 404 uses its dedicated title fallback rather than the page schema.
put(join(content, '404.md'), 'CUSTOM_404_BODY\n'); next(); publish();
assert.match(readFileSync(join(output, '404.html'), 'utf8'), /CUSTOM_404_BODY/);
// Public projection excludes missing visibility before body validation.
put(source, 'BODY_ONLY_CANARY [[missing]] ![[missing.png]] {{< unknown_fixture >}}\n');
put(join(root, 'external/outside.md'), 'EXCLUDED_EXTERNAL_CANARY\n');
put(join(content, 'index.md'), 'EXCLUDED_ROOT_CANARY\n');
put(join(root, 'standalone/about.md'), 'EXCLUDED_STANDALONE_CANARY\n');
put(join(content, '404.md'), 'EXCLUDED_404_CANARY\n');
const publicSource = join(content, 'notes/public.md');
put(publicSource, note('[[Destination#Evidence]]\nPUBLIC_BODY\n', 'title: Public\nvisibility: public\ntags: [shared]\n'));
const publicFlags = ['--audience', 'public', '--fresh-output'];
next(); check(null, ['--audience', 'public']);
let report = publish(publicFlags);
assert.ok(report.entries.some(e => e.status === 'excluded' && e.source === source));
for (const path of ['notes/public/index.html', 'tags/shared/index.html', 'static/pixel.png', 'search-index.json', 'graph.json', 'content-index.json']) assert.ok(existsSync(join(output, path)), path);
for (const [name, value] of Object.entries(snapshot(output))) {
  assert.doesNotMatch(name, /body\/|outside\/|about\//);
  if (value) assert.doesNotMatch(Buffer.from(value[0], 'hex').toString('utf8'), /BODY_ONLY_CANARY|EXCLUDED_\w+_CANARY|unknown_fixture/);
}
assert.deepEqual(JSON.parse(readFileSync(join(output, 'graph.json'), 'utf8')).edges, [{ source: 'public', target: 'target' }]);
assert.equal(existsSync(join(output, '.lattice-cache')), false);
next(); invoke('build', ['--audience', 'public'], 1);
configure(); put(config, readFileSync(config, 'utf8').replace('static_allowlist = ["pixel.png"]\n', ''));
reject('io', ['--audience', 'public'], publicFlags);
configure();
put(source, '---\nvisibility: private\nbroken header\n---\nBODY_ONLY_CANARY\n');
reject('publication_visibility', ['--audience', 'public'], publicFlags);
put(source, 'BODY_ONLY_CANARY\n');
// A planned static/redirect replacement cannot launder an excluded identity.
for (const owner of ['static', 'redirect']) {
  if (owner === 'static') {
    put(join(content, 'notes/body/index.html'), 'PUBLIC_REPLACEMENT');
    configure('allow_missing_frontmatter = true\n', 'static_dir = notes\n');
    put(config, readFileSync(config, 'utf8').replace('["pixel.png"]', '["body/index.html"]'));
  } else put(join(content, 'notes/redirect.md'), note('PUBLIC_REPLACEMENT', 'title: Redirect\nvisibility: public\nredirect_from: [/notes/body/]\n'));
  next();
  report = JSON.parse(invoke('inventory', ['--format', 'json', ...publicFlags]).stdout);
  assert.ok(report.entries.some(e => e.status === 'planned' && e.path === 'notes/body/index.html'), `${owner} collision control`);
  for (const link of ['[Denied](/notes/body/)', '[Denied fragment](/notes/body/#heading)', '[[body]]']) {
    put(publicSource, note(link));
    const r = invoke('check', ['--format', 'json', '--audience', 'public'], 1);
    assert.match(r.stdout, /public audience boundary/);
    assert.ok(JSON.parse(r.stdout).violations.some(v => v.kind === 'publication_visibility'));
    invoke('build', publicFlags, 1);
  }
  put(publicSource, note('PUBLIC_BODY'));
  if (owner === 'static') { unlinkSync(join(content, 'notes/body/index.html')); configure(); }
  else unlinkSync(join(content, 'notes/redirect.md'));
}
put(join(content, 'notes/target.md'), note('PUBLIC_TARGET', 'title: Target\nvisibility: public\naliases: [body]\n'));
put(publicSource, note('[[body]]'));
check('publication_visibility', ['--audience', 'public']);
invoke('build', publicFlags, 1);
console.log('Optional frontmatter: strict defaults, typed config/cache transitions, schema parity, parser boundaries, line positions, validation and public exclusion/collision isolation passed');
