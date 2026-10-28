import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'lattice-cli-json-'));
const cli = fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
for (const path of ['content/posts', 'templates', 'data', 'dist']) mkdirSync(join(root, path), { recursive: true });
const write = (path, text) => writeFileSync(join(root, path), text);
const config = 'title = JSON fixture\nbase_url = https://example.test\ntemplates_dir = templates\ndata_dir = data\ncollections_file = collections.cfg\noutput_dir = dist\n';
write('site.cfg', config);
write('collections.cfg', '[posts]\ndir = content/posts\nschema = title:String\n');
write('templates/page.html', '{{content}}');
write('templates/index.html', '{{content}}');
write('content/posts/note.md', '---\ntitle: Note\n---\nA published passage.\n');
for (const path of ['index.html', '.lattice-cache.json', 'manifest.json']) write(`dist/${path}`, `existing ${path}`);
const outputSnapshot = () => readdirSync(join(root, 'dist'), { recursive: true }).sort().map(path => [path, readFileSync(join(root, 'dist', path), 'utf8')]);
const before = outputSnapshot();
const run = (args) => {
  const result = spawnSync(process.execPath, [cli, 'check', 'content', ...(args.includes('-c') ? [] : ['-c', 'site.cfg']), ...args], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  assert.ifError(result.error);
  assert.deepEqual(outputSnapshot(), before, 'check must preserve existing output and metadata');
  return result;
};
const json = (args, expectedStatus, kind, path, line = null) => {
  const result = run(['--format', 'json', ...args]);
  assert.equal(result.status, expectedStatus, result.stdout + result.stderr);
  assert.equal(result.stderr, '');
  // Parse the entire stdout: consumers must not strip logs, ANSI or prose.
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.summary.total, parsed.violations.length);
  if (kind) {
    assert.equal(parsed.violations.length, 1);
    const violation = parsed.violations[0];
    assert.equal(violation.kind, kind);
    assert.equal(violation.path, path);
    assert.equal(violation.line, line);
    assert.ok(violation.message.length > 0);
    assert.deepEqual(parsed.summary.by_type, [{ kind, count: 1 }]);
    assert.deepEqual(parsed.summary.by_file, [{ path, count: 1 }]);
  } else assert.deepEqual(parsed.violations, []);
  return parsed;
};
json([], 0);
json(['-o', 'fresh-dist'], 0);
assert.equal(existsSync(join(root, 'fresh-dist')), false);
write('content/posts/note.md', '---\ntitle: Note\n---\n[[Missing]]\n');
json([], 1, 'broken_wikilink', 'content/posts/note.md', 4);
write('content/posts/note.md', '---\ntitle: Note\n---\nA published passage.\n');
json(['-c', 'missing-"config.cfg', '-o', 'fresh-dist'], 1, 'io', 'missing-"config.cfg');
assert.equal(existsSync(join(root, 'fresh-dist')), false);
write('invalid.cfg', 'title = Test\nbase_url = https://example.test\ninvalid line\n');
json(['-c', 'invalid.cfg'], 1, 'config', 'invalid.cfg', 3);
write('invalid.cfg', 'title = Test\nbase_url = https://example.test\npage_size = nope\n');
json(['-c', 'invalid.cfg'], 1, 'config', 'invalid.cfg');
write('invalid.cfg', 'base_url = https://example.test\n');
json(['-c', 'invalid.cfg'], 1, 'config', 'invalid.cfg');
json(['--collections', 'missing-collections.cfg'], 1, 'io', 'missing-collections.cfg');
write('invalid-collections.cfg', '[posts]\ninvalid line\n');
json(['--collections', 'invalid-collections.cfg'], 1, 'collections', 'invalid-collections.cfg', 2);
write('inline.cfg', config.replace('collections_file = collections.cfg\n', '') + '\n[[collections]]\nname = posts\ndir = content/posts\nschema = title:UnknownType\n');
json(['-c', 'inline.cfg'], 1, 'collections', 'inline.cfg');
const cleanText = run([]);
assert.equal(cleanText.status, 0);
assert.ok(cleanText.stdout.includes('[lattice] checking content') && cleanText.stdout.includes('check passed'));
const invalidText = run(['-c', 'invalid.cfg']);
assert.equal(invalidText.status, 1);
assert.ok(invalidText.stdout.includes('invalid.cfg') && invalidText.stdout.includes("missing required field 'title'"));
// Authors need the failing array item, not just the enclosing array type.
// Keep the root field's source line and the existing one-violation-per-field contract.
write('collections.cfg', '[posts]\ndir = content/posts\nschema = title:String, topics:Optional[Array[Enum["guide","journal"]]], scores:Optional[Array[Int(min=1,max=5)]], grid:Optional[Array[Array[Bool]]]\n');
for (const [fence, separator] of [['---', ':'], ['+++', '=']]) {
  for (const [field, value, detail] of [
    ['topics', '["guide", "guid", "journl"]', 'topics: expected Array[Enum["guide","journal"]] but got incompatible value; item 2: expected one of Enum["guide","journal"], got "guid"'],
    ['scores', '[1, 9, 0]', 'scores: expected Array[Int(min=1, max=5)] but got incompatible value; item 2: expected Int in range [1, 5], got: 9'],
    ['grid', '[[true], [false, "no"]]', 'grid: expected Array[Array[Bool]] but got incompatible value; item 2: expected Array[Bool] but got incompatible value; item 2: expected Bool but got incompatible value'],
    ['scores', '"wrong container"', 'scores: expected Array[Int(min=1, max=5)] but got incompatible value'],
  ]) {
    write('content/posts/note.md', `${fence}\ntitle ${separator} "Note"\n${field} ${separator} ${value}\n${fence}\nBody.\n`);
    const report = json([], 1, 'schema', 'content/posts/note.md', 3);
    assert.equal(report.violations[0].message, detail);
    const text = run([]);
    assert.equal(text.status, 1);
    assert.ok(text.stdout.includes(detail), text.stdout);
    if (field === 'topics') {
      const build = spawnSync(process.execPath, [cli, 'build', 'content', '-c', 'site.cfg'], { cwd: root, encoding: 'utf8', timeout: 30_000 });
      assert.ifError(build.error);
      assert.equal(build.status, 1, build.stdout + build.stderr);
      assert.ok((build.stdout + build.stderr).includes(detail), build.stdout + build.stderr);
      assert.deepEqual(outputSnapshot(), before, 'invalid array must not replace published output');
    }
  }
  write('content/posts/note.md', `${fence}\ntitle ${separator} "Note"\ntopics ${separator} ["guide", "journal"]\nscores ${separator} [1, 5]\ngrid ${separator} [[true], []]\n${fence}\nBody.\n`);
  json([], 0);
}
console.log('CLI JSON: clean/content/config/collections/I/O results, array item diagnostics, locations, summaries, escaping, text compatibility and read-only output passed');
