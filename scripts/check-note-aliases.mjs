import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, unlinkSync, existsSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = mkdtempSync(join(tmpdir(), 'lattice-note-aliases-'));
const cli = resolve('_build/js/debug/build/kurisu/lattice/cmd/main/main.js');
const content = join(root, 'content');
mkdirSync(join(content, 'notes'), { recursive: true });
mkdirSync(join(root, 'templates'));
mkdirSync(join(content, 'data'));
writeFileSync(join(root, 'templates/page.html'), '<html><body>{{content}}{{backlinks}}</body></html>');
writeFileSync(join(root, 'collections.cfg'), `[notes]\nschema = title:String,tags:Optional[Array[String]]\ndir = ${content}/notes\n`);
const config = join(root, 'site.cfg');
writeFileSync(config, `wikilink_aliases = true\ntitle = Knowledge\nbase_url = https://example.test\ntemplate_dir = ${root}/templates\ncollections_file = ${root}/collections.cfg\n`);
const output = join(root, 'dist');
const note = join(content, 'notes/research.md');
writeFileSync(note, '---\ntitle: Research\ntags: [Research]\naliases: ["Field Guide", "Research Handbook"]\n---\n## Evidence\n\nMeasured results.\n');
writeFileSync(join(content, 'notes/hub.md'), '---\ntitle: Hub\n---\nRead [[Field Guide#Evidence|the evidence]] and [[Research Handbook]].\n');
function run(command, extra = []) {
 return spawnSync(process.execPath, [cli, command, content, '-o', output, '--config', config, ...extra], { cwd: root, encoding: 'utf8' });
}
const checked = run('check');
assert.equal(checked.status, 0, checked.stdout + checked.stderr);
assert.equal(existsSync(output), false, 'check must not publish alias output');
const built = run('build', ['--strict-wikilinks']);
assert.equal(built.status, 0, built.stdout + built.stderr);
assert.match(readFileSync(join(output, 'notes/hub/index.html'), 'utf8'), /href="\/notes\/research\/#evidence"/);
assert.match(readFileSync(join(output, 'notes/research/index.html'), 'utf8'), /href="\/notes\/hub\/"/);
assert.ok(existsSync(join(output, 'tags/research/index.html')));
const graph = JSON.parse(readFileSync(join(output, 'graph.json'), 'utf8'));
assert.deepEqual(graph.edges, [{ source: 'hub', target: 'research' }]);
console.log('Note aliases: canonical links, fragments, backlinks and graph identity passed');
// Alias edits must update cached referring pages and strict final fragments.
writeFileSync(note, '---\ntitle: Research\ntags: [Research]\naliases: ["Field Guide", "Research Handbook", "Research.MD"]\n---\n## Evidence\n\nChanged results.\n');
assert.equal(run('build').status, 0);
assert.equal(run('check').status, 0);
writeFileSync(note, '---\ntitle: Research\ntags: [Research]\naliases: ["Different Name"]\n---\n## Evidence\n');
assert.notEqual(run('check').status, 0);
assert.equal(run('build').status, 0); // existing ordinary-build warning policy
assert.doesNotMatch(readFileSync(join(output, 'notes/hub/index.html'), 'utf8'), /href="\/notes\/research\//);
function snapshot(dir) {
 return readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).map(entry =>
  [entry.name, entry.isDirectory() ? snapshot(join(dir, entry.name)) : readFileSync(join(dir, entry.name)).toString('base64')]);
}
const before = snapshot(output);
for (const aliases of ['["Hub"]', '[""]', '["Bad#heading"]', '["Bad|label"]', '[42]', '"Field Guide"']) {
 writeFileSync(note, `---\ntitle: Research\ntags: [Research]\naliases: ${aliases}\n---\n## Evidence\n`);
 const failure = run('check', ['--format', 'json']);
 assert.notEqual(failure.status, 0, aliases);
 assert.match(failure.stdout, /aliases/);
 assert.ok(JSON.parse(failure.stdout).violations.some(v => v.path === note && v.line === 4));
 assert.notEqual(run('build').status, 0, aliases);
 assert.deepEqual(snapshot(output), before);
}
writeFileSync(note, '---\ntitle: Research\ntags: [Research]\naliases: ["Field Guide", "Research Handbook"]\n---\n## Renamed\n');
assert.match(run('check').stdout + run('check').stderr, /fragment/);
writeFileSync(note, '---\ntitle: Research\ntags: [Research]\ndraft: true\naliases: ["Field Guide", "Research Handbook"]\n---\n## Evidence\n');
assert.notEqual(run('check').status, 0);
assert.equal(run('check', ['--drafts']).status, 0);
writeFileSync(note, '---\ntitle: Research\ntags: [Research]\naliases: ["Field Guide", "Research Handbook"]\n---\n## Evidence\n');
writeFileSync(join(content, 'notes/other.md'), '---\ntitle: Other\naliases: ["FIELD GUIDE"]\n---\nOther.\n');
const collision = run('check', ['--format', 'json']);
assert.notEqual(collision.status, 0);
assert.match(collision.stdout, /declared by multiple pages/);
assert.notEqual(run('build').status, 0);
console.log('Alias collisions, malformed metadata, draft policy, cached edits and strict fragment checks passed');

unlinkSync(join(content, 'notes/other.md'));
mkdirSync(join(content, 'standalone'));
writeFileSync(join(content, 'index.md'), '---\ntitle: Home\naliases: ["Start Here"]\n---\nWelcome.\n');
writeFileSync(join(content, 'standalone/manual.md'), '---\ntitle: Manual\naliases: ["User Handbook"]\n---\n## Setup\nInstructions.\n');
writeFileSync(join(content, 'notes/hub.md'), '---\ntitle: Hub\n---\n[[Start Here]] [[User Handbook#Setup]] [[Field Guide#Evidence]]\n');
assert.equal(run('check').status, 0);
assert.equal(run('build', ['--strict-wikilinks']).status, 0);
const hub = readFileSync(join(output, 'notes/hub/index.html'), 'utf8');
assert.match(hub, /href="\/"/);
assert.match(hub, /href="\/manual\/#setup"/);
console.log('Root and standalone aliases retain their published routes');

// Disabled mode retains ordinary schema validation instead of reserving the field globally.
writeFileSync(config, readFileSync(config, 'utf8').replace('wikilink_aliases = true', 'wikilink_aliases = false'));
assert.match(run('check').stdout + run('check').stderr, /unrecognized field/);
