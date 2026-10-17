import { createNoteRuntime } from '../../examples/wasm_note/host.mjs';
import { runNoteCases, fenceLanguageProbe } from '../../scripts/note-cases.mjs';
import { runSearchCases } from '../../scripts/search-cases.mjs';

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
  const { renderNote: render, searchContent: search } = await createNoteRuntime(await response.arrayBuffer());
  const count = runNoteCases(render, assert);
  const searchCount = runSearchCases(search, assert);
  const destinationHtml = render(
    '---\ntitle: Destinations\n---\n' + [
      "[x](/doc\"data-probe=\"yes?x=%22&plus=a+b#frag)",
      "![x](/img.png\"data-probe=\"yes?x=%2F&plus=a+b#frag)",
      "[x](/doc\\\"data-probe=\\\"yes?x=%22&plus=a+b#frag)",
      "![x](/img.png\\\"data-probe=\\\"yes?x=%2F&plus=a+b#frag)",
      "<https://example.test/a\"b?x=%22&plus=a+b#frag>",
      "[[soil|Guide]]",
    ].join('\n\n'),
    'destinations.md',
    "{\"soil\":\"/wiki\\\"data-probe=\\\"yes?x=%2f&plus=a+b#frag\"}",
  ).html;
  self.postMessage({
    destinationHtml,
    fenceLanguageHtml: render(fenceLanguageProbe.source, 'fence-language.md', '{}').html,
    ok: true, count, searchCount, worker: self instanceof DedicatedWorkerGlobalScope,
    userAgent: navigator.userAgent,
    imageAltHtml: render('---\ntitle: Image\n---\n![He said "hello" & waved](/plot.png)', 'image-alt.md', '{}').html,
  });
} catch (error) {
  self.postMessage({ ok: false, error: String(error), stack: error.stack });
}
