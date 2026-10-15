// Experimental WASM GC string ABI; no Node or browser-specific services.
// Trust source text and link-map URLs: raw HTML passes through, and dangerous
// URL schemes are not rejected. Sanitize untrusted output under the host's
// policy before DOM insertion; WASM/worker isolation does not make HTML safe.
export async function createNoteRuntime(bytes) {
  const module = await WebAssembly.compile(bytes, {
    builtins: ['js-string'], importedStringConstants: '_',
  });
  if (WebAssembly.Module.imports(module).length !== 0) {
    throw new TypeError('note renderer requires unexpected host imports');
  }
  const exports = WebAssembly.Module.exports(module);
  if (exports.length !== 2 || !['render_note', 'search_content'].every(
    name => exports.some(entry => entry.name === name && entry.kind === 'function'))) {
    throw new TypeError('unexpected note renderer exports');
  }
  const instance = await WebAssembly.instantiate(module, {});
  const renderNote = (source, sourceFile, linksJson) => {
    if (![source, sourceFile, linksJson].every((value) => typeof value === 'string')) {
      throw new TypeError('note source, source name and link map must be strings');
    }
    return JSON.parse(instance.exports.render_note(source, sourceFile, linksJson));
  };
  const searchContent = (indexJson, query, tagsJson = '[]', limit = 10) => {
    if (![indexJson, query, tagsJson].every(value => typeof value === 'string') ||
        !Number.isInteger(limit) || limit < -2147483648 || limit > 2147483647) {
      throw new TypeError('search input must be strings and a signed 32-bit integer limit');
    }
    return JSON.parse(instance.exports.search_content(indexJson, query, tagsJson, limit));
  };
  return { renderNote, searchContent };
}

// Preserve the original callable rendering interface.
export async function createNoteRenderer(bytes) {
  return (await createNoteRuntime(bytes)).renderNote;
}

export async function createContentSearcher(bytes) {
  return (await createNoteRuntime(bytes)).searchContent;
}
