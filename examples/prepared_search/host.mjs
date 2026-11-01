// One explicitly owned index per runtime. The existing stateless note ABI stays separate.
export async function createPreparedSearcher(bytes) {
  const module = await WebAssembly.compile(bytes, {
    builtins: ['js-string'], importedStringConstants: '_',
  });
  const expected = ['replace_index', 'query_index', 'clear_index'];
  const exports = WebAssembly.Module.exports(module);
  if (WebAssembly.Module.imports(module).length !== 0 || exports.length !== expected.length ||
      !expected.every(name => exports.some(item => item.name === name && item.kind === 'function'))) {
    throw new TypeError('unexpected prepared search ABI');
  }
  const { exports: runtime } = await WebAssembly.instantiate(module, {});
  return {
    replace(index) {
      // Even invalid host input invalidates the previous index.
      runtime.clear_index();
      if (typeof index !== 'string') throw new TypeError('index must be a string');
      if (!runtime.replace_index(index)) throw new TypeError('invalid content index');
    },
    clear() { runtime.clear_index(); },
    search(query, tags = '[]', limit = 50) {
      if (typeof query !== 'string' || typeof tags !== 'string' ||
          !Number.isInteger(limit) || limit < -2147483648 || limit > 2147483647) {
        throw new TypeError('query and tags must be strings and limit a signed 32-bit integer');
      }
      return JSON.parse(runtime.query_index(query, tags, limit));
    },
  };
}
