import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';
import { createNoteRenderer } from '../examples/wasm_note/host.mjs';
import { runNoteCases } from './note-cases.mjs';

if (isMainThread) {
  assert.equal(process.argv.length, 4, 'provide WASM and JavaScript renderer paths');
  const js = await import(pathToFileURL(resolve(process.argv[3])));
  const jsCount = runNoteCases((...args) => JSON.parse(js.render_note(...args)), assert);
  const worker = new Worker(new URL(import.meta.url), { workerData: await readFile(process.argv[2]) });
  const count = await new Promise((resolveResult, reject) => {
    let received;
    const timeout = setTimeout(() => {
      void worker.terminate();
      reject(new Error('WASM note worker timed out'));
    }, 30_000);
    worker.once('message', (value) => { received = value; });
    worker.once('error', (error) => { clearTimeout(timeout); reject(error); });
    worker.once('exit', (code) => {
      clearTimeout(timeout);
      if (code !== 0 || received === undefined) {
        reject(new Error(`WASM note worker exited ${code} without results`));
      } else {
        resolveResult(received);
      }
    });
  });
  assert.equal(count, jsCount);
  console.log(`${count} supplied-note assertions passed on JS and one reused WASM GC worker instance`);
} else {
  const render = await createNoteRenderer(workerData);
  assert.throws(() => render(null, 'note.md', '{}'), TypeError);
  parentPort.postMessage(runNoteCases(render, assert));
}
