import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, readdirSync, existsSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = mkdtempSync(join(tmpdir(), 'lattice-image-embeds-'));
const content = join(root, 'content');
const output = join(root, 'dist');
for (const dir of ['notes', 'data', 'attachments/figures', 'standalone']) mkdirSync(join(content, dir), { recursive: true });
mkdirSync(join(root, 'templates'));
writeFileSync(join(root, 'templates/page.html'), '<html><body>{{content}}</body></html>');
writeFileSync(join(root, 'collections.cfg'), `[notes]\nschema = title:String\ndir = ${content}/notes\n`);
const config = join(root, 'site.cfg');
writeFileSync(config, `title = Notebook\nbase_url = https://example.test\nstatic_dir = ./attachments/\ntemplates_dir = ${root}/templates\ncollections_file = ${root}/collections.cfg\ncontent_index_file = content-index.json\n`);
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jS1sAAAAASUVORK5CYII=', 'base64');
for (const file of ['diagram.png', 'figures/café "100%.png']) writeFileSync(join(content, 'attachments', file), png);
const source = join(content, 'notes/guide.md');
writeFileSync(source, '---\ntitle: Guide\n---\n## Figure\n![[diagram.png]]\n\n![[figures/café "100%.png]]\n\n[[other]]\n');
writeFileSync(join(content, 'notes/other.md'), '---\ntitle: Other\n---\nOther note.\n');
writeFileSync(join(content, 'index.md'), '---\ntitle: Home\n---\n![[attachments/diagram.png]]\n');
writeFileSync(join(content, 'standalone/manual.md'), '---\ntitle: Manual\n---\n![[diagram.png]]\n');
writeFileSync(join(content, '404.md'), '---\ntitle: Missing\n---\n![[attachments/diagram.png]]\n');
writeFileSync(join(content, 'notes/draft.md'), '---\ntitle: Draft\ndraft: true\n---\n![[private.png]]\n');
const cli = process.env.LATTICE_NATIVE_CLI ?? resolve('_build/js/debug/build/kurisu/lattice/cmd/main/main.js');
const run = (cmd, flags = []) => spawnSync(process.env.LATTICE_NATIVE_CLI ? cli : process.execPath,
  [...(process.env.LATTICE_NATIVE_CLI ? [] : [cli]), cmd, content, '-o', output, '-c', config, ...flags], { encoding: 'utf8', cwd: root });
const ok = (cmd, flags = []) => { const r = run(cmd, flags); assert.equal(r.status, 0, r.stdout + r.stderr); return r; };
ok('check');
assert.equal(existsSync(output), false);
for (const flags of [[], [], ['--force']]) {
  ok('build', flags);
  const html = readFileSync(join(output, 'notes/guide/index.html'), 'utf8');
  assert.match(html, /<img src="\/attachments\/diagram.png" alt="diagram.png"/);
  assert.ok(html.includes('/attachments/figures/caf%C3%A9%20%22100%25.png'));
  assert.match(html, /href="\/notes\/other\/"/);
  assert.deepEqual(readFileSync(join(output, 'attachments/diagram.png')), png);
  assert.match(readFileSync(join(output, '404.html'), 'utf8'), /<img src="\/attachments\/diagram.png"/);
  assert.deepEqual(JSON.parse(readFileSync(join(output, 'graph.json'), 'utf8')).edges, [{ source: 'guide', target: 'other' }]);
}
const snapshot = path => readdirSync(path, { withFileTypes: true }).flatMap(e => e.isDirectory() ? snapshot(join(path, e.name)) : [[join(path, e.name), readFileSync(join(path, e.name)).toString('base64')]]).sort();
const before = snapshot(output);
assert.notEqual(run('build', ['--drafts']).status, 0);
assert.deepEqual(snapshot(output), before);
for (const [target, message] of [['missing.png', /not found/], ['../secret.png', /unsupported/], ['https://example.test/x.png', /unsupported/], ['other', /unsupported/], ['document.pdf', /unsupported/], ['vector.svg', /unsupported/], ['diagram.png|300', /unsupported/], ['diagram.png#part', /unsupported/]]) {
  writeFileSync(source, `---\ntitle: Guide\n---\n\`![[${target}]]\`\n\n![[${target}]]\n`);
  const checked = run('check', ['--format', 'json']);
  assert.notEqual(checked.status, 0, target);
  const violations = JSON.parse(checked.stdout).violations;
  const issue = violations.find(v => v.message.includes('image embed'));
  assert.ok(issue, checked.stdout + checked.stderr);
  assert.equal(issue.kind, 'broken_wikilink');
  assert.equal(issue.line, 6);
  assert.match(issue.message, message);
  assert.notEqual(run('build').status, 0);
  assert.deepEqual(snapshot(output), before);
}
writeFileSync(source, '---\ntitle: Guide\n---\n![[diagram.png]]\n');
writeFileSync(join(content, 'attachments/figures/diagram.png'), png);
mkdirSync(join(content, 'attachments/attachments'));
writeFileSync(join(content, 'attachments/attachments/diagram.png'), png);
assert.match(run('check').stdout + run('check').stderr, /ambiguous/);
writeFileSync(source, '---\ntitle: Guide\n---\n![[attachments/diagram.png]]\n');
// The other pages still use the ambiguous basename: fix those explicitly too.
writeFileSync(join(content, 'standalone/manual.md'), '---\ntitle: Manual\n---\n![[attachments/diagram.png]]\n');
ok('check'); ok('build');
unlinkSync(join(content, 'attachments/diagram.png'));
assert.notEqual(run('check').status, 0, 'stale published files cannot satisfy an embed');
console.log('Image embeds: static-only resolution, bytes, canonical paths, cached builds, draft policy, ambiguity, unsupported syntax and read-only diagnostics passed');
