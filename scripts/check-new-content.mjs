import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'lattice-new-content-'));
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
for (const path of ['content/notes', 'templates', 'data']) mkdirSync(join(root, path), { recursive: true });
const write = (path, text) => writeFileSync(join(root, path), text);
write('content/lattice.conf', 'title = Scaffold fixture\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\noutput_dir = dist\n');
write('templates/page.html', '{{content}}');
write('templates/index.html', '{{content}}');
const values = ['true', 'FALSE', '42', '3.14', 'draft # review', '#private', '[draft]', '', ' padded ', 'a,b', "it's ready", 'café'];
const fields = ['title:String', 'empty:String(maxlen=0)', 'count:Int', 'draft:Bool', 'date:Date', 'labels:Array[String]', 'optional:Optional[String]',
  'rating:Float(min=0.0,max=5.0)', 'balance:Int(max=-1)', 'offset:Float(max=-0.5)', 'ratings:Array[Float(min=1.0,max=5.0)]',
  'tiny:Float(min=0.0000001,max=0.0000002)', 'huge:Float(min=1000000000000000000000.0)', 'negative_tiny:Float(max=-0.0000001)'];
for (const [i, value] of values.entries()) {
  fields.push(`value${i}:Enum[${JSON.stringify(value)}]`, `list${i}:Array[Enum[${JSON.stringify(value)}]]`);
}
write('collections.cfg', `[notes]\ndir = content/notes\nschema = ${fields.join(',')}\n`);
const run = (args, expected = 0) => {
  const result = spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(result.error);
  assert.equal(result.status, expected, result.stdout + result.stderr);
  return result.stdout;
};
run(['new', 'notes', '--name', 'first-note']);
const source = readFileSync(join(root, 'content/notes/first-note.md'), 'utf8');
// Validate through the real parser and collection schema, not a second YAML parser.
assert.deepEqual(JSON.parse(run(['check', '--format', 'json'])).violations, []);
assert.equal(existsSync(join(root, 'dist')), false);
for (const [i, value] of values.entries()) {
  assert.ok(source.includes(`value${i}: ${JSON.stringify(value)}\n`));
  assert.ok(source.includes(`list${i}:\n  - ${JSON.stringify(value)}\n`));
}
assert.ok(source.includes('empty: ""\n'));
assert.ok(source.includes('count: 0\n') && source.includes('draft: false\n'));
assert.ok(source.includes('rating: 0.0\n') && source.includes('balance: -1\n') && source.includes('offset: -0.5\n'));
assert.ok(source.includes('# optional: \n'));
run(['new', 'notes', '--name', 'first-note'], 1);
assert.equal(readFileSync(join(root, 'content/notes/first-note.md'), 'utf8'), source);
run(['build']);
assert.ok(existsSync(join(root, 'dist/notes/first-note/index.html')));
console.log(`New content: typed string/enum and bounded numeric scalars/arrays, escaping, check/build and overwrite refusal passed (${root})`);
