import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import {layout_graph} from '../_build/js/debug/build/kurisu/lattice/examples/local_graph/local_graph.js';
const bytes=readFileSync(new URL('../_build/wasm-gc/debug/build/kurisu/lattice/examples/local_graph/local_graph.wasm',import.meta.url));
const module=await WebAssembly.compile(bytes,{builtins:['js-string'],importedStringConstants:'_'});
const wasm=(await WebAssembly.instantiate(module,{})).exports.layout_graph;
for(const [shape,n] of [['chain',100],['star',500],['clusters',2000],['dense',500],['star',10000]]){
 const nodes=Array.from({length:n},(_,i)=>({slug:`n${i}`,url:`/n${i}/`,title:`Note ${i}`}));
 const edges=[];
 for(let i=1;i<n;i++){
  const source=shape==='star'?0:shape==='clusters'?Math.floor((i-1)/20)*20:i-1;
  edges.push({source:`n${source}`,target:`n${i}`});
  if(shape==='dense')for(let j=0;j<i;j++)edges.push({source:`n${j}`,target:`n${i}`});
 }
 const input=JSON.stringify({nodes,edges});const times={};let expected;
 for(const [name,fn] of [['js',layout_graph],['wasm',wasm]]){
  const elapsed=[];
  for(let i=0;i<5;i++){const start=performance.now();const result=JSON.parse(fn(input,'/n0/'));elapsed.push(performance.now()-start);assert.ok(result.nodes.length<=31);assert.equal(result.nodes[0].url,'/n0/');assert.ok(result.nodes.every(n=>Number.isFinite(n.x)&&Number.isFinite(n.y)));if(expected)assert.deepEqual(result,expected);expected=result;}
  times[name]=elapsed.sort((a,b)=>a-b)[2].toFixed(2);
 }
 console.log(JSON.stringify({shape,n,edges:edges.length,bytes:input.length,visible:expected.nodes.length,medianMs:times}));
}
assert.deepEqual(JSON.parse(layout_graph('{bad','/a/')),{});
const graph={nodes:[{slug:'a',title:'A',url:'/a/'},{slug:'b',title:'B',url:'/b/'}],edges:[{source:'b',target:'a'},{source:'b',target:'a'},{source:'a',target:'hidden'}]};
const view=JSON.parse(layout_graph(JSON.stringify(graph),'/a/'));assert.equal(view.nodes.length,2);assert.deepEqual(view.edges,[{source:'b',target:'a'}]);
assert.equal(layout_graph(JSON.stringify(graph),'/missing/'),'{}');
console.log('Local graph: deterministic JS/WASM parity, bounded neighborhoods, incoming links, deduplication and invalid input passed');
