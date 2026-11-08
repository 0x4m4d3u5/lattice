// Synthetic CLI stream lifecycle regression. No private vault inputs.
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { closeSync, mkdirSync, mkdtempSync, openSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const cli = resolve(process.env.LATTICE_PIPE_CLI ?? '_build/js/debug/build/kurisu/lattice/cmd/main/main.js');
const root = mkdtempSync(join(tmpdir(), 'lattice-piped-json-'));
const put = (p, text) => writeFileSync(join(root, p), text);
const count = 4000;
const args = command => [command, 'content', '-c', 'site.cfg', '--format', 'json'];
const gate = join(root, 'gate.cjs');

function file(command, status) {
  const path = join(root, 'stdout.json');
  const fd = openSync(path, 'w');
  let result;
  try {
    result = spawnSync(process.execPath, [cli, ...command], {
      cwd: root, stdio: ['ignore', fd, 'pipe'], timeout: 30_000,
    });
  } finally { closeSync(fd); }
  assert.ifError(result.error);
  assert.equal(result.signal, null);
  assert.equal(result.status, status);
  assert.equal(result.stderr.toString(), '');
  return readFileSync(path);
}

async function pipe(command, status, mode = 'normal') {
  const gated = mode === 'gated';
  const child = spawn(process.execPath, [...(gated ? ['--require', gate] : []), cli, ...command], {
    cwd: root, stdio: ['ignore', 'pipe', 'pipe', ...(gated ? ['ipc'] : [])],
  });
  const chunks = [], errors = [];
  let timedOut = false, ready = false;
  const timeout = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, 30_000);
  child.stderr.on('data', data => errors.push(data));
  if (mode === 'closed') child.stdout.destroy();
  else if (mode === 'slow') {
    // Keep the real pipe backpressured: consume only 1 KiB per event-loop turn.
    // Start on readable, not a guessed startup delay.
    let reading = false;
    const consume = () => {
      const data = child.stdout.read(1024);
      if (data) { chunks.push(data); setImmediate(consume); }
      else reading = false;
    };
    child.stdout.on('readable', () => {
      if (!reading) { reading = true; setImmediate(consume); }
    });
  } else child.stdout.on('data', data => chunks.push(data));
  if (gated) child.on('message', message => {
    assert.equal(message, 'write-pending');
    ready = true;
    // Old process.exit terminates before this write can be released. With
    // exitCode the process survives to drain exactly the same stdout bytes.
    child.send('release', () => {});
  });
  try {
    const [code, signal] = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('close', (code, signal) => resolve([code, signal]));
    });
    assert.equal(timedOut, false, `${mode}: CLI must terminate without hanging handles`);
    assert.equal(signal, null);
    if (mode === 'closed') {
      // MoonBit println uses Node Console, whose default ignoreErrors swallows
      // EPIPE. Preserve that policy: status reports validation, not receipt.
      assert.equal(code, status);
      assert.equal(Buffer.concat(errors).toString(), '');
    } else {
      assert.equal(code, status);
      assert.equal(Buffer.concat(errors).toString(), '');
      if (gated) assert.equal(ready, true);
    }
    return Buffer.concat(chunks);
  } finally { clearTimeout(timeout); }
}

async function parity(command, status, validate, modes = ['normal', 'gated']) {
  const expected = file(command, status);
  validate(JSON.parse(expected.toString('utf8')));
  for (const mode of modes) {
    const actual = await pipe(command, status, mode);
    assert.equal(actual.equals(expected), true,
      `${command[0]} ${mode}: pipe ${actual.length} bytes != file ${expected.length} bytes`);
    validate(JSON.parse(actual.toString('utf8')));
  }
  return expected;
}

try {
  mkdirSync(join(root, 'content/notes'), { recursive: true });
  mkdirSync(join(root, 'content/data'), { recursive: true });
  mkdirSync(join(root, 'content/templates'), { recursive: true });
  put('content/templates/page.html', '{{content}}');
  put('content/templates/index.html', '{{content}}');
  put('site.cfg', 'title = Pipe fixture\nbase_url = https://example.test\ncollections_file = collections.cfg\noutput_dir = dist\n');
  put('collections.cfg', '[notes]\ndir = content/notes\nschema = title:String\n');
  put('content/notes/café-雪.md', `---\ntitle: Synthetic\n${Array.from({ length: count }, (_, i) => `extra_${i}: value`).join('\n')}\n---\nSynthetic body.\n`);
  put('gate.cjs', `// Hold the first stream write until the parent releases it via IPC.
const original = process.stdout._write.bind(process.stdout);
process.stdout._write = function(chunk, encoding, callback) {
  process.stdout._write = original;
  process.once('message', message => {
    if (message !== 'release') throw new Error('unexpected gate message');
    original(chunk, encoding, callback);
    process.disconnect();
  });
  process.send('write-pending');
};\n`);
  const check = value => {
    assert.equal(value.summary.total, count, JSON.stringify(value.violations.filter(v => v.kind !== "schema")));
    assert.equal(value.violations.length, count);
    assert.ok(value.violations.every(v => v.kind === 'schema' && v.path === 'content/notes/café-雪.md'));
  };
  // Gate first: deterministic pre-fix failure even on a fast pipe reader.
  const large = await parity(args('check'), 1, check, ['gated', 'normal', 'slow']);
  assert.ok(large.length > 512_000, 'fixture must exceed pipe buffering');
  assert.ok(large.includes(Buffer.from('café-雪')), 'pipe must carry multibyte UTF-8, not only ASCII escapes');
  await parity(args('inventory'), 1, value => {
    assert.equal(value.ready, false);
    assert.equal(value.diagnostics.length, count + 1);
    assert.equal(value.diagnostics.filter(d => d.severity === "error").length, count);
    assert.equal(value.diagnostics.filter(d => d.severity === "warning").length, 1);
  }, ['gated', 'normal', 'slow']);
  await pipe(args('check'), 1, 'closed');
  put('content/notes/café-雪.md', '---\ntitle: Synthetic\n---\nSynthetic body.\n');
  await parity(args('check'), 0, value => assert.equal(value.summary.total, 0));
  await pipe(args('check'), 0, 'closed');
  const inventory = await parity(args('inventory'), 0, value => assert.equal(value.ready, true));
  put('before.json', inventory); put('after.json', inventory);
  await parity(['inventory-diff', '--before', 'before.json', '--after', 'after.json', '--format', 'json'], 0,
    value => { assert.equal(value.ready, true); assert.deepEqual(value.added, []); });
  await parity(['inventory-diff', '--format', 'json'], 1, value => assert.equal(value.ready, false));
  put('site.cfg', 'base_url = https://example.test\n');
  await parity(args('check'), 1, value => assert.equal(value.violations[0].kind, 'config'));
  await parity(args('inventory'), 1, value => assert.equal(value.ready, false));
  // Fatal argument errors retain their existing text format, status, and return.
  const invalid = ['inventory', '--format', 'invalid'];
  const text = file(invalid, 1);
  assert.match(text.toString(), /inventory --format must be text or json/);
  assert.deepEqual(await pipe(invalid, 1, 'gated'), text);
  console.log(`Piped JSON: ${count} UTF-8 diagnostics, ${large.length} bytes, gated/normal/slow pipe parity, closed pipe, success and fatal paths passed`);
} finally { rmSync(root, { recursive: true }); }
