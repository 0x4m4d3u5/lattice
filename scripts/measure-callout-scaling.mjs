import { performance } from 'node:perf_hooks';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
// Manual synthetic scaling probe; no timing thresholds in CI.
const { render_note } = await import(pathToFileURL(resolve(process.argv[2])));
for (const layout of ["separated", "adjacent"]) {
for (const n of [64,128,256,512]) {
  const source = '---\ntitle: Scaling\n---\nIntro `sample`.\n\n' +
    (`{{< callout type="note" >}}\nRemember **bold** and \`field\`.\n${layout === 'separated' ? '\n' : ''}`).repeat(n) +
    'Example ``\n{{< callout type="note" >}}\nLiteral body.\n``.\n';
  const samples=[];
  for (let i=0;i<3;i++) {
    const start=performance.now(); const result=JSON.parse(render_note(source,'scale.md','{}'));
    if (result.diagnostics.length) throw new Error('unexpected diagnostics');
    samples.push(performance.now()-start);
  }
  samples.sort((a,b)=>a-b);
  console.log(JSON.stringify({layout,callouts:n,median_ms:Number(samples[1].toFixed(2))}));
}
}
