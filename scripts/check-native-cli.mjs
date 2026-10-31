// Execute the native binary, rather than inferring CLI support from type checking.
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
const binary = resolve('_build/native/debug/build/kurisu/lattice/cmd/main/main.exe');
const root = mkdtempSync(join(tmpdir(), 'lattice-native-cli-'));
function run(args, cwd = root) {
  const result = spawnSync(binary, args, { cwd, encoding: 'utf8' });
  assert.equal(result.status, 0, `${args.join(' ')}: ${result.error ?? ''}\n${result.stdout}\n${result.stderr}`);
  return result.stdout;
}
try {
  run(['init', 'site']);
  const site = join(root, 'site');
  run(['check'], site);
  run(['build', '--strict-wikilinks'], site);
  const inventory = JSON.parse(run(['inventory', '--format', 'json'], site));
  assert.equal(inventory.ready, true);
  assert.ok(inventory.entries.some(entry => entry.path === 'posts/welcome/index.html' && entry.status === 'planned'));
  assert.match(readFileSync(join(site, 'dist', 'posts', 'welcome', 'index.html'), 'utf8'), /<html/i);
  console.log('Native CLI init, check, strict build and JSON inventory passed');
} finally {
  rmSync(root, { recursive: true, force: true });
}
