import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';
import { createNoteRuntime } from '../examples/wasm_note/host.mjs';
import { runNoteCases } from './note-cases.mjs';
import { runSearchCases } from './search-cases.mjs';

if (isMainThread) {
  assert.equal(process.argv.length, 4, 'provide WASM and JavaScript renderer paths');
  const js = await import(pathToFileURL(resolve(process.argv[3])));
  const jsResponses = [];
  const jsCount = {
    notes: runNoteCases((...args) => JSON.parse(js.render_note(...args)), assert),
    search: runSearchCases((...args) => {
      const result = JSON.parse(js.search_content(...args));
      jsResponses.push(result);
      return result;
    }, assert),
    responses: jsResponses,
  };
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
  assert.deepEqual(count, jsCount);
  console.log(`${count.notes} supplied-note and ${count.search} retrieval assertions passed on JS and one reused WASM GC worker instance`);
} else {
  const { renderNote: render, searchContent: search } = await createNoteRuntime(workerData);
  assert.throws(() => render(null, 'note.md', '{}'), TypeError);
  assert.throws(() => search(null, 'recovery'), TypeError);
  assert.throws(() => search('[]', 'recovery', '[]', 1.5), TypeError);
  assert.throws(() => search('[]', 'recovery', '[]', 2147483648), TypeError);
  const responses = [];
  const notes = runNoteCases(render, assert);
  const searchCount = runSearchCases((...args) => {
    const result = search(...args);
    responses.push(result);
    return result;
  }, assert);
  parentPort.postMessage({ notes, search: searchCount, responses });
}
