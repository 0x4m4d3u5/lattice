// Experimental WASM GC string ABI; no Node or browser-specific services.
// Trust source text and link-map URLs: raw HTML passes through, and dangerous
// URL schemes are not rejected. Sanitize untrusted output under the host's
// policy before DOM insertion; WASM/worker isolation does not make HTML safe.
export async function createNoteRenderer(bytes) {
  const module = await WebAssembly.compile(bytes, {
    builtins: ['js-string'], importedStringConstants: '_',
  });
  if (WebAssembly.Module.imports(module).length !== 0) {
    throw new TypeError('note renderer requires unexpected host imports');
  }
  const exports = WebAssembly.Module.exports(module);
  if (exports.length !== 1 || exports[0].name !== 'render_note' || exports[0].kind !== 'function') {
    throw new TypeError('unexpected note renderer exports');
  }
  const instance = await WebAssembly.instantiate(module, {});
  return (source, sourceFile, linksJson) => {
    if (![source, sourceFile, linksJson].every((value) => typeof value === 'string')) {
      throw new TypeError('note source, source name and link map must be strings');
    }
    return JSON.parse(instance.exports.render_note(source, sourceFile, linksJson));
  };
}
