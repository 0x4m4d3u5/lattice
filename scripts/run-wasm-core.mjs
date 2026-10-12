import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';

const fixtures = [
  'render_note', 'validate_note', 'validate_links', 'template_note', 'parse_toml_note',
];

if (isMainThread) {
  assert.equal(process.argv.length, 3, 'provide the compiled WASM fixture path');
  const bytes = await readFile(process.argv[2]);
  // Only bytes cross into the worker. Filesystem/environment/CLI APIs are absent
  // from the module's host imports, checked before executing any fixture.
  const worker = new Worker(new URL(import.meta.url), { workerData: bytes });
  const result = await new Promise((resolve, reject) => {
    let received;
    const timeout = setTimeout(() => {
      void worker.terminate();
      reject(new Error('WASM core worker timed out'));
    }, 30_000);
    worker.once('message', (value) => { received = value; });
    worker.once('error', (error) => { clearTimeout(timeout); reject(error); });
    worker.once('exit', (code) => {
      clearTimeout(timeout);
      if (code !== 0 || received === undefined) {
        reject(new Error(`WASM core worker exited ${code} without completing its results`));
      } else {
        resolve(received);
      }
    });
  });
  assert.deepEqual(result, fixtures.map((name) => [name, 1]));
  console.log(`${process.argv[2]}: ${fixtures.length} core fixtures passed in a worker`);
} else {
  const module = await WebAssembly.compile(workerData);
  assert.deepEqual(WebAssembly.Module.imports(module), [], 'pure core has host imports');
  assert.deepEqual(
    WebAssembly.Module.exports(module).map((entry) => [entry.name, entry.kind]).sort(),
    fixtures.map((name) => [name, 'function']).sort(),
    'fixture export set changed',
  );
  const results = fixtures.map((name) => {
    const instance = new WebAssembly.Instance(module, {});
    return [name, instance.exports[name]()];
  });
  parentPort.postMessage(results);
}
