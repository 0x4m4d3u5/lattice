import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
// Manual synthetic scaling probe; correctness assertions, no timing thresholds.
const { render_note } = await import(pathToFileURL(resolve(process.argv[2])));
for (const token of ['[x](()', '![x](()', '[x](/a(b))']) {
  for (const repeats of [1000, 2000, 4000, 8000]) {
    const source = '---\ntitle: Scaling\n---\n' + token.repeat(repeats);
    const expected = '<p>' + (token === '[x](/a(b))' ? '<a href="/a(b)">x</a>' : token).repeat(repeats) + '</p>\n';
    const samples = [];
    for (let i = 0; i < 5; i++) {
      const start = performance.now();
      const result = JSON.parse(render_note(source, 'scale.md', '{}'));
      samples.push(performance.now() - start);
      assert.deepEqual(result, { html: expected, diagnostics: [] });
    }
    samples.sort((a, b) => a - b);
    console.log(JSON.stringify({ token, repeats, median_ms: Number(samples[2].toFixed(2)) }));
  }
}
