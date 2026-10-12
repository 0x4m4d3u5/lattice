import { createNoteRenderer } from '../../examples/wasm_note/host.mjs';
import { runNoteCases } from '../../scripts/note-cases.mjs';

// Compare JSON values without depending on object property order.
const normalize = (value) => {
  if (Array.isArray(value)) return value.map(normalize);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, normalize(value[key])]));
  }
  return value;
};
const assert = {
  deepEqual(actual, expected) {
    if (JSON.stringify(normalize(actual)) !== JSON.stringify(normalize(expected))) {
      throw new Error(`note comparison failed: ${JSON.stringify({ actual, expected }).slice(0, 800)}`);
    }
  },
};
try {
  const response = await fetch('/renderer.wasm');
  if (!response.ok) throw new Error(`renderer fetch failed: ${response.status}`);
  const render = await createNoteRenderer(await response.arrayBuffer());
  const count = runNoteCases(render, assert);
  self.postMessage({
    ok: true, count, worker: self instanceof DedicatedWorkerGlobalScope,
    userAgent: navigator.userAgent,
  });
} catch (error) {
  self.postMessage({ ok: false, error: String(error), stack: error.stack });
}
