import assert from 'node:assert/strict';
import { buildCatalogue } from '../../examples/wiki_search/catalogue.js';
const page = (url, more = {}) => ({ title: 'A note', url, sections: [{ heading: '', body: 'Text' }], ...more });
const entries = [null, {}, page('/untitled/', { title: '  ' }), page('/wiki/notes/one/', { collection: 'Guides', description: '<img src=x>' }),
  page('/wiki/notes/one/'), page('/overwritten/', { sections: [] }),
  page('/legacy/', { sections: undefined, body: 'Legacy text' }),
  page('/empty/', { sections: undefined, body: '' }),
  ...['javascript:alert(1)', 'data:text/html,x', 'https://elsewhere.test/', 'https://name:pass@example.test/private/',
    'http://[', '/wiki/static/search/', '/a/?draft=1', '/a/#invented'].map(url => page(url))];
assert.deepEqual(buildCatalogue(entries, 'https://example.test/wiki/static/search/', './').map(p => [p.url, p.collection, p.description]), [
  ['https://example.test/wiki/notes/one/', 'Guides', '<img src=x>'], ['https://example.test/legacy/', 'Pages', ''],
]);
assert.deepEqual(buildCatalogue({}, 'https://example.test/', '/wiki/'), []);

assert.deepEqual(buildCatalogue([
  page('/', { collection: '_root' }), page('/about/', { collection: '_standalone' }),
  page('/custom/', { collection: '_Research' }),
], 'https://example.test/', '/static/search/').map(p => [p.url, p.collection]).sort(), [
  ['https://example.test/', 'Pages'], ['https://example.test/about/', 'Pages'], ['https://example.test/custom/', '_Research'],
]);
console.log('Catalogue: readable page labels, generated/overwritten exclusion, legacy body, same-origin URLs, deduplication and metadata passed');
