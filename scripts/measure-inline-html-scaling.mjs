import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
// Manual synthetic scaling probe; output assertions, no timing thresholds.
const { render_note } = await import(pathToFileURL(resolve(process.argv[2])));
for (const [fragment, expectedFragment] of [
  ['<span title="1 > 0">x</span>', '<span title="1 > 0">x</span>'],
  ["<span title='", "&lt;span title='"],
]) {
  for (const repeats of [1000, 2000, 4000, 8000]) {
    const body = 'Before ' + fragment.repeat(repeats);
    const expected = '<p>Before ' + expectedFragment.repeat(repeats) + '</p>\n';
    const samples = [];
    for (let i = 0; i < 5; i++) {
      const start = performance.now();
      const result = JSON.parse(render_note('---\ntitle: Scaling\n---\n' + body, 'scale.md', '{}'));
      samples.push(performance.now() - start);
      assert.deepEqual(result, { html: expected, diagnostics: [] });
    }
    samples.sort((a, b) => a - b);
    console.log(JSON.stringify({ fragment, repeats, median_ms: Number(samples[2].toFixed(2)) }));
  }
}
