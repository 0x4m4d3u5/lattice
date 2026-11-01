import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createPreparedSearcher } from '../examples/prepared_search/host.mjs';
import { search_content } from '../_build/js/debug/build/kurisu/lattice/examples/wasm_note/wasm_note.js';
import * as js from '../_build/js/debug/build/kurisu/lattice/examples/prepared_search/prepared_search.js';
const bytes = readFileSync(new URL('../_build/wasm-gc/debug/build/kurisu/lattice/examples/prepared_search/prepared_search.wasm', import.meta.url));
const wasm = await createPreparedSearcher(bytes);
const independent = await createPreparedSearcher(bytes);
const pages = [
  { title: 'Recovery', url: '/ops/', tags: ['Database'], aliases: ['Handbook'], sections: [{ heading: 'Restore', body: 'Verify café 🌱 snapshots.', fragment: 'restore' }, { heading: 'Repeat', body: 'Restore snapshots again.' }] },
  { title: 'Legacy', url: '/legacy/', tags: [], body: 'restore snapshots' },
  { title: 'Excluded', url: '/excluded/', tags: [], body: 'private', sections: [] },
  { title: 'Duplicate A', url: '/dup/', tags: [], aliases: ['Alternate'], sections: [{ heading: 'One', body: 'restore', fragment: 'one' }] },
  { title: 'Duplicate B', url: '/dup/', tags: [], sections: [{ heading: 'Two', body: 'restore', fragment: 'two' }] },
];
for (const entries of [pages, [], pages.slice(0, 1), pages]) {
  const index = JSON.stringify(entries);
  wasm.replace(index); assert.equal(js.replace_index(index), true);
  for (const query of ['restore', 'handbook', 'handbook snapshots', 'café 🌱', 'private', 'alternate', '', 'missing']) {
    for (const tags of ['[]', '["database"]', '["missing"]', '{', '[3]']) {
      for (const limit of [0, 1, 50, 100, -1]) {
        const expected = JSON.parse(search_content(index, query, tags, limit));
        assert.deepEqual(wasm.search(query, tags, limit), expected);
        assert.deepEqual(JSON.parse(js.query_index(query, tags, limit)), expected);
      }
    }
  }
}
assert(independent.search('restore').error, 'instances must not share an index');
for (const invalid of ['{', '{}', '[{}]', JSON.stringify([{ ...pages[0], aliases: [2] }]), JSON.stringify([{ ...pages[0], sections: null }])]) {
  wasm.replace(JSON.stringify(pages)); js.replace_index(JSON.stringify(pages));
  assert.throws(() => wasm.replace(invalid)); assert.equal(js.replace_index(invalid), false);
  assert(wasm.search('restore').error); assert(JSON.parse(js.query_index('restore', '[]', 50)).error);
}
wasm.replace(JSON.stringify(pages)); assert.throws(() => wasm.replace(null)); assert(wasm.search('restore').error);
wasm.replace('[]'); wasm.clear(); wasm.clear(); js.clear_index();
assert(wasm.search('restore').error); assert(JSON.parse(js.query_index('restore', '[]', 50)).error);
for (const args of [[null], ['restore', null], ['restore', '[]', 1.5], ['restore', '[]', 2147483648]]) assert.throws(() => wasm.search(...args));
console.log('Prepared JS/WASM parity, replacement, invalidation and instance ownership passed');
