import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const native = process.env.LATTICE_NATIVE_CLI;
const cli = native ?? process.env.LATTICE_CLI ?? fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const root = mkdtempSync(join(tmpdir(), 'lattice-local-links-'));
for (const dir of ['content/notes', 'content/static', 'content/data', 'templates', 'dist']) mkdirSync(join(root, dir), { recursive: true });
writeFileSync(join(root, 'collections.cfg'), '[notes]\ndir = content/notes\nschema = title:String\n');
writeFileSync(join(root, 'site.cfg'), 'title = Links\nbase_url = https://example.test/wiki\ntemplates_dir = templates\ncollections_file = collections.cfg\noutput_dir = dist\n');
const template = '<html><head><title>{{title}}</title></head><body>{{body_no_h1}}</body></html>';
writeFileSync(join(root, 'templates/page.html'), template);
writeFileSync(join(root, 'templates/404.html'), '<html>{{content}}</html>');
const put = (name, body, fields = '') => writeFileSync(join(root, `content/notes/${name}.md`), `---\ntitle: ${name}\n${fields}---\n${body}\n`);
put('target', '## Visible\nPublic content.\n\n<div id="résumé:2026">Unicode ID.</div>\n');
put('draft', '## Secret\nPrivate.', 'draft: true\n');
writeFileSync(join(root, 'content/static/a b.pdf'), 'synthetic attachment');
writeFileSync(join(root, 'dist/sentinel'), 'keep');
const run = (command, flags = []) => spawnSync(native ? cli : process.execPath,
  [...(native ? [] : [cli]), command, 'content', '-c', 'site.cfg', '--collections', 'collections.cfg', ...flags],
  { cwd: root, encoding: 'utf8', timeout: 30000 });
const ok = (command, flags = []) => { const r = run(command, flags); assert.equal(r.status, 0, r.stdout + r.stderr); return r; };
const snapshot = (dir = join(root, 'dist')) => Object.fromEntries(readdirSync(dir, { recursive: true, withFileTypes: true }).filter(e => e.isFile()).map(e => [join(e.parentPath, e.name), readFileSync(join(e.parentPath, e.name), 'hex')]));
const valid = '[Sibling](../target/#visible)\n\n[Root](/wiki/notes/target/?view=1#r%C3%A9sum%C3%A9:2026)\n\n[File](../target/index.html#visible)\n\n[Asset](../../static/a%20b.pdf#page=1)\n\n[External](https://invalid.example/missing) [Network](//invalid.example/missing) [Email](mailto:nobody@example.test)\n\n## Here\n[Self](#here) [Query](?q=1#here)\n\n`[Example](../missing/)`\n';
put('source', valid);
const before = snapshot(); ok('check', ['--local-links', '--format', 'json']); assert.deepEqual(snapshot(), before);
ok('build', ['--strict-local-links']); const built = snapshot(); ok('build', ['--strict-local-links']); assert.deepEqual(snapshot(), built); ok('build', ['--strict-local-links', '--force']); assert.deepEqual(snapshot(), built);
const invalid = [
 ['../missing/', 'not in the publication plan'],
 ['../target/#absent', "fragment 'absent'"],
 ['../draft/#secret', 'not in the publication plan'],
 ['/notes/target/', 'outside the configured publication base path'],
 ['../target.md', 'not in the publication plan'],
 ['../bad%ZZ/', 'malformed percent'],
 ['../target%2findex.html', 'encoded separators'],
 ['../target%09/', 'control characters'],
];
for (const [url, message] of invalid) {
 put('source', `[Broken](${url})`);
 const audit = run('check', ['--local-links', '--format', 'json']); assert.equal(audit.status, 1, audit.stdout + audit.stderr);
 const result = JSON.parse(audit.stdout.slice(audit.stdout.indexOf('{')));
 const error = result.violations.find(v => v.kind === 'broken_local_link'); assert.ok(error, audit.stdout); assert.ok(error.message.includes(message), error.message); assert.equal(error.line, 4); assert.ok(error.column > 0);
 const freshOutput = join(root, 'unpublished');
 const fresh = run('build', ['--strict-local-links', '-o', freshOutput]); assert.equal(fresh.status, 1); assert.equal(existsSync(freshOutput), false);
 const failed = run('build', ['--strict-local-links']); assert.equal(failed.status, 1); assert.match(failed.stdout + failed.stderr, /E014/); assert.deepEqual(snapshot(), built);
 ok('check'); // The new audit is opt-in.
}
ok('build'); // Existing permissive publication remains available.
put('source', 'Text[^note].\n\n[^note]: [Missing](../footnote-missing/)');
assert.equal(run('check', ['--local-links']).status, 1);
put('source', '[Draft](../draft/#secret)'); ok('check', ['--local-links', '--drafts']);
put('source', valid); ok('build', ['--strict-local-links']); assert.deepEqual(snapshot(), built);
// Published output, not Markdown heading guesses, decides whether a fragment exists.
writeFileSync(join(root, 'templates/page.html'), template.replace('{{body_no_h1}}', '<p>Body omitted.</p>'));
assert.equal(run('check', ['--local-links']).status, 1); assert.deepEqual(snapshot(), built);
writeFileSync(join(root, 'templates/page.html'), template.replace('<head>', '<head><base href="/elsewhere/">'));
const base = run('check', ['--local-links']); assert.equal(base.status, 1); assert.match(base.stdout, /base elements/);
writeFileSync(join(root, 'templates/page.html'), template);
// Final static ownership can replace a target. Only the replacement's fragment counts.
writeFileSync(join(root, 'site.cfg'), readFileSync(join(root, 'site.cfg'), 'utf8') + 'static_dir = notes\n');
mkdirSync(join(root, 'content/notes/target'), { recursive: true });
writeFileSync(join(root, 'content/notes/target/index.html'), '<h2 id="replacement">Replacement</h2>');
put('source', '[Old](../target/#visible)'); assert.equal(run('check', ['--local-links']).status, 1);
put('source', '[New](../target/#replacement)'); ok('check', ['--local-links']);
// A replaced source is not an authored publication candidate.
mkdirSync(join(root, 'content/notes/source'), { recursive: true });
writeFileSync(join(root, 'content/notes/source/index.html'), '<p>Replacement source</p>');
put('source', '[Missing](../missing/)'); ok('check', ['--local-links']);
const explanation = spawnSync(native ? cli : process.execPath, [...(native ? [] : [cli]), 'explain', 'E014'], { encoding: 'utf8' });
assert.equal(explanation.status, 0); assert.match(explanation.stdout, /published page URL/);
console.log('Local Markdown URLs: opt-in JSON/text diagnostics, base paths, encoded routes/fragments, assets, drafts, final ownership, cached/forced parity and nonmutation passed');
