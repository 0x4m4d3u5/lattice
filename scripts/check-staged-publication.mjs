import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, statSync, chmodSync, symlinkSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = mkdtempSync(join(tmpdir(), 'lattice-staged-publication-'));
const content = join(root, 'content');
const out = join(root, 'dist');
mkdirSync(content);
mkdirSync(join(content, 'data'));
const config = join(root, 'site.cfg');
writeFileSync(config, 'title = Staged publication\nbase_url = https://example.test\n');
const cli = process.env.LATTICE_CLI || fileURLToPath(new URL('../_build/js/debug/build/kurisu/lattice/cmd/main/main.js', import.meta.url));
const run = (hook) => spawnSync(process.execPath, [...(hook ? ['--import', hook] : []), cli, 'build', content, '-o', out, '--config', config, '--force'], { encoding: 'utf8', cwd: root });
const snapshot = () => {
  const files = {};
  const walk = (dir, prefix = '') => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const key = prefix + entry.name;
      if (entry.isDirectory()) walk(join(dir, entry.name), key + '/');
      else files[key] = readFileSync(join(dir, entry.name)).toString('hex');
    }
  };
  walk(out); return files;
};
for (const name of ['index', 'alpha', 'beta']) writeFileSync(join(content, name + '.md'), `---\ntitle: ${name}\ndate: 2026-01-01\n---\nOld bytes.\n`);
let result = run(); assert.equal(result.status, 0, result.stdout + result.stderr);
const before = snapshot();
for (const name of ['index', 'alpha', 'beta']) writeFileSync(join(content, name + '.md'), `---\ntitle: ${name}\ndate: 2026-01-01\n---\nNew bytes.\n`);
const hook = join(root, 'inject.mjs');
writeFileSync(hook, `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
const write = fs.writeFileSync;
let writes = 0;
fs.writeFileSync = function(path, bytes, ...args) {
  if (++writes === 2) {
    write(path, bytes.subarray ? bytes.subarray(0, 7) : bytes.slice(0, 7), ...args);
    throw new Error('injected staging write failure');
  }
  return write(path, bytes, ...args);
};
syncBuiltinESMExports();
`);
result = run(hook);
assert.notEqual(result.status, 0, 'injected write failure must reject publication');
assert.match(result.stdout + result.stderr, /injected staging write failure/);
assert.deepEqual(snapshot(), before, 'late staging failure must preserve every existing file');
const inject = code => {
  writeFileSync(hook, `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
${code}
syncBuiltinESMExports();
`);
  return run(hook);
};
// Exclusive creation failure must never remove someone else's payload.
result = inject(`
const open = fs.openSync;
fs.openSync = function(path, flags, ...args) {
  if (flags === 'wx') throw Object.assign(new Error('injected exclusive-open failure'), { code: 'EEXIST' });
  return open(path, flags, ...args);
};`);
assert.notEqual(result.status, 0);
assert.match(result.stdout + result.stderr, /injected exclusive-open failure/);
assert.deepEqual(snapshot(), before);
// Failure while staging the final manifest must also leave every file untouched.
result = inject(`
const write = fs.writeFileSync;
fs.writeFileSync = (path, bytes, ...args) => {
  if (Buffer.from(bytes).toString().includes('"out":')) throw new Error('injected manifest staging failure');
  return write(path, bytes, ...args);
};`);
assert.notEqual(result.status, 0);
assert.match(result.stdout + result.stderr, /injected manifest staging failure/);
assert.deepEqual(snapshot(), before);
// A close error happens before publication, even after every byte was written.
result = inject(`
const close = fs.closeSync;
let first = true;
fs.closeSync = fd => { close(fd); if (first) { first = false; throw new Error('injected close failure'); } };`);
assert.notEqual(result.status, 0);
assert.match(result.stdout + result.stderr, /injected close failure/);
assert.deepEqual(snapshot(), before);
for (const failAt of [1, 2]) {
  result = inject(`
const rename = fs.renameSync;
let count = 0;
fs.renameSync = (source, target) => {
  if (++count === ${failAt}) throw new Error('injected replacement failure');
  return rename(source, target);
};`);
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /injected replacement failure/);
  const after = snapshot();
  assert.deepEqual(Object.keys(after).sort(), Object.keys(before).sort(), 'no stages left behind');
  assert.equal(after['.lattice-cache'], before['.lattice-cache']);
  assert.equal(after['.lattice-manifest.json'], before['.lattice-manifest.json']);
  if (failAt === 1) assert.deepEqual(after, before);
  else {
    const changed = Object.keys(after).filter(key => after[key] !== before[key]);
    assert.equal(changed.length, 1, 'only the completed replacement may change');
    const html = Buffer.from(after[changed[0]], 'hex').toString();
    assert.ok(html.includes('New bytes.') && html.endsWith('</html>\n'), 'replacement is complete');
  }
}
// Recovery publishes complete HTML/binary bytes, preserving existing mode bits.
const alpha = join(out, 'posts/alpha/index.html');
chmodSync(alpha, 0o640);
mkdirSync(join(content, 'static'));
writeFileSync(join(content, 'static/pixel.bin'), Buffer.from([0, 255, 128, 13, 10]));
result = run(); assert.equal(result.status, 0, result.stdout + result.stderr);
assert.equal(statSync(alpha).mode & 0o777, 0o640);
assert.ok(readFileSync(alpha, 'utf8').includes('New bytes.'));
assert.deepEqual(readFileSync(join(out, 'static/pixel.bin')), Buffer.from([0, 255, 128, 13, 10]));
unlinkSync(join(out, 'style.css')); // Remove only this fixture's generated optional file.
const recovered = snapshot();
// Optional stylesheet replacement still warns and permits required publication.
result = inject(`
const rename = fs.renameSync;
fs.renameSync = (source, target) => {
  if (target.endsWith('/style.css')) throw new Error('injected optional replacement failure');
  return rename(source, target);
};`);
assert.equal(result.status, 0, result.stdout + result.stderr);
assert.match(result.stdout + result.stderr, /could not write optional output.*injected optional replacement failure/);
assert.deepEqual(snapshot(), recovered);
// A final-component symlink must not redirect a write into unrelated content.
const foreign = join(root, 'foreign.bin');
writeFileSync(foreign, 'user-owned sentinel');
symlinkSync(foreign, join(out, 'static/foreign.bin'));
writeFileSync(join(content, 'static/foreign.bin'), 'new asset');
const withLink = snapshot();
result = run(); assert.notEqual(result.status, 0);
assert.match(result.stdout + result.stderr, /not a regular file/);
assert.equal(readFileSync(foreign, 'utf8'), 'user-owned sentinel');
assert.deepEqual(snapshot(), withLink);
result = inject(`
const open = fs.openSync;
const write = fs.writeFileSync;
let collided = false;
fs.openSync = function(path, flags, ...args) {
  if (flags === 'wx' && !collided) {
    collided = true;
    const fd = open(path, 'wx');
    write(fd, 'collision sentinel');
    fs.closeSync(fd);
    throw Object.assign(new Error('injected payload collision'), { code: 'EEXIST' });
  }
  return open(path, flags, ...args);
};`);
assert.notEqual(result.status, 0);
assert.match(result.stdout + result.stderr, /retained stage directory/);
const collision = snapshot();
const extra = Object.keys(collision).filter(key => !(key in withLink));
assert.equal(extra.length, 1);
assert.equal(Buffer.from(collision[extra[0]], 'hex').toString(), 'collision sentinel');
for (const [key, value] of Object.entries(withLink)) assert.equal(collision[key], value);
console.log('Staged publication: partial write, exclusive open, close, replacement, recovery, binary, mode, optional and symlink regressions passed. Fixture: ' + root);
