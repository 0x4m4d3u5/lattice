///|
// Node's event loop cannot serve HTTP while the CLI runs its synchronous watcher.
// Keep HTTP/SSE in a Worker; a bounded shared-memory handshake preserves the
// native adapter's synchronous API. Builtin modules work in MoonBit ESM output.
// No child process or additional dependency is installed. Process exit ends the
// worker too. Files are read only from the configured output root.
extern "js" fn serve_control_js(operation : String, port : Int, root : String) -> Bool =
  #| function serveControl(operation, port, root) {
  #|   const key = Symbol.for('kurisu.lattice.serve.node.v1');
  #|   const previous = globalThis[key];
  #|   const running = previous && Atomics.load(previous.status, 0) === 1;
  #|   if (operation === 'running') return Boolean(running);
  #|   if (operation === 'reload') {
  #|     if (running) previous.worker.postMessage('reload');
  #|     return Boolean(running);
  #|   }
  #|   if (operation === 'stop') {
  #|     if (!previous) return false;
  #|     if (running) {
  #|       Atomics.store(previous.status, 0, 2);
  #|       previous.worker.postMessage('stop');
  #|       Atomics.wait(previous.status, 0, 2, 2000);
  #|     }
  #|     if (Atomics.load(previous.status, 0) !== 3) previous.worker.terminate();
  #|     delete globalThis[key];
  #|     return false;
  #|   }
  #|   if (running || !Number.isInteger(port) || port < 1 || port > 65535) return false;
  #|   if (previous) previous.worker.terminate();
  #|   if (typeof process === 'undefined' || typeof process.getBuiltinModule !== 'function') return false;
  #|   const { Worker } = process.getBuiltinModule('node:worker_threads');
  #|   const status = new Int32Array(new SharedArrayBuffer(4));
  #|   function serverWorker() {
  #|     const { parentPort, workerData } = require('node:worker_threads');
  #|     const http = require('node:http');
  #|     const fs = require('node:fs');
  #|     const path = require('node:path');
  #|     const status = new Int32Array(workerData.status);
  #|     const root = path.resolve(workerData.root);
  #|     const clients = new Set();
  #|     const script = "<script>new EventSource('/__lattice_reload').onmessage=function(){location.reload()}</script>";
  #|     const mime = {
  #|       '.html': 'text/html; charset=utf-8', '.htm': 'text/html; charset=utf-8',
  #|       '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  #|       '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
  #|       '.xml': 'application/xml; charset=utf-8', '.txt': 'text/plain; charset=utf-8',
  #|       '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  #|       '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp',
  #|       '.avif': 'image/avif', '.ico': 'image/x-icon', '.wasm': 'application/wasm',
  #|       '.woff': 'font/woff', '.woff2': 'font/woff2', '.pdf': 'application/pdf',
  #|     };
  #|     const signal = value => { Atomics.store(status, 0, value); Atomics.notify(status, 0); };
  #|     const contained = (base, file) => {
  #|       const relative = path.relative(base, file);
  #|       return relative === '' || (!path.isAbsolute(relative) && relative !== '..' && !relative.startsWith('..' + path.sep));
  #|     };
  #|     const resolveFile = relative => {
  #|       const file = path.resolve(root, relative);
  #|       if (!contained(root, file)) throw Object.assign(new Error('Outside output'), { code: 'ESCAPE' });
  #|       const realRoot = fs.realpathSync(root);
  #|       const realFile = fs.realpathSync(file);
  #|       if (!contained(realRoot, realFile)) throw Object.assign(new Error('Outside output'), { code: 'ESCAPE' });
  #|       return realFile;
  #|     };
  #|     const server = http.createServer((request, response) => {
  #|       const send = (code, bytes, type = 'text/plain; charset=utf-8') => {
  #|         response.writeHead(code, { 'Content-Type': type, 'Content-Length': bytes.length, 'Cache-Control': 'no-store' });
  #|         response.end(request.method === 'HEAD' ? undefined : bytes);
  #|       };
  #|       const text = (code, message) => send(code, Buffer.from(message));
  #|       const sendFile = (file, code) => {
  #|         let bytes = fs.readFileSync(file);
  #|         const type = mime[path.extname(file).toLowerCase()] || 'application/octet-stream';
  #|         if (type.startsWith('text/html')) {
  #|           const html = bytes.toString('utf8');
  #|           bytes = Buffer.from(/<\/body\s*>/i.test(html) ? html.replace(/<\/body\s*>/i, script + '$&') : html + script);
  #|         }
  #|         send(code, bytes, type);
  #|       };
  #|       if (request.method !== 'GET' && request.method !== 'HEAD') {
  #|         response.setHeader('Allow', 'GET, HEAD'); text(405, 'Method not allowed'); return;
  #|       }
  #|       const raw = request.url || '/';
  #|       const queryAt = raw.indexOf('?');
  #|       const rawPath = queryAt < 0 ? raw : raw.slice(0, queryAt);
  #|       let decoded;
  #|       try { decoded = decodeURIComponent(rawPath); }
  #|       catch { text(400, 'Invalid URL encoding'); return; }
  #|       if (!decoded.startsWith('/') || decoded.startsWith('//') || decoded.includes('\\') || decoded.includes('\0') || decoded.split('/').includes('..')) {
  #|         text(403, 'Path outside output'); return;
  #|       }
  #|       if (decoded === '/__lattice_reload') {
  #|         response.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store', 'Connection': 'keep-alive' });
  #|         if (request.method === 'HEAD') { response.end(); return; }
  #|         response.write(': connected\n\n');
  #|         clients.add(response);
  #|         response.on('close', () => clients.delete(response));
  #|         response.on('error', () => { clients.delete(response); response.destroy(); });
  #|         return;
  #|       }
  #|       try {
  #|         let file = resolveFile('.' + decoded);
  #|         if (fs.statSync(file).isDirectory()) {
  #|           if (!decoded.endsWith('/')) {
  #|             response.writeHead(301, { Location: rawPath + '/' + (queryAt < 0 ? '' : raw.slice(queryAt)), 'Cache-Control': 'no-store' });
  #|             response.end(); return;
  #|           }
  #|           file = resolveFile('.' + decoded + 'index.html');
  #|         }
  #|         if (!fs.statSync(file).isFile()) { text(404, 'Not found'); return; }
  #|         sendFile(file, 200);
  #|       } catch (error) {
  #|         if (error.code === 'ESCAPE' || error.code === 'EACCES' || error.code === 'EPERM') { text(403, 'Path unavailable'); return; }
  #|         if (error.code !== 'ENOENT' && error.code !== 'ENOTDIR') { text(500, 'Unable to read output'); return; }
  #|         try {
  #|           const fallback = resolveFile('404.html');
  #|           if (fs.statSync(fallback).isFile()) { sendFile(fallback, 404); return; }
  #|         } catch {}
  #|         text(404, 'Not found');
  #|       }
  #|     });
  #|     const close = failed => {
  #|       if (failed) signal(-1);
  #|       for (const response of clients) response.end();
  #|       clients.clear();
  #|       server.close(() => { if (!failed) signal(3); parentPort.close(); });
  #|       server.closeAllConnections();
  #|     };
  #|     server.on('error', () => close(true));
  #|     process.on('uncaughtException', () => { signal(-1); process.exit(1); });
  #|     process.on('unhandledRejection', () => { signal(-1); process.exit(1); });
  #|     process.on('exit', () => { if (Atomics.load(status, 0) !== 3) signal(-1); });
  #|     parentPort.on('message', message => {
  #|       if (message === 'stop') close(false);
  #|       else if (message === 'reload') {
  #|         for (const response of clients) {
  #|           if (!response.write('data: reload\n\n')) { clients.delete(response); response.destroy(); }
  #|         }
  #|       }
  #|     });
  #|     try {
  #|       if (fs.existsSync(root) && !fs.statSync(root).isDirectory()) throw new Error('Output root is not a directory');
  #|       server.listen(workerData.port, '127.0.0.1', () => signal(1));
  #|     } catch { close(true); }
  #|   }
  #|   let worker;
  #|   try {
  #|     worker = new Worker('(' + serverWorker.toString() + ')()', {
  #|       eval: true, workerData: { port, root, status: status.buffer },
  #|     });
  #|     worker.on('error', () => { Atomics.store(status, 0, -1); Atomics.notify(status, 0); });
  #|     worker.on('exit', () => {
  #|       if (Atomics.load(status, 0) !== 3) { Atomics.store(status, 0, -1); Atomics.notify(status, 0); }
  #|     });
  #|     globalThis[key] = { worker, status };
  #|     Atomics.wait(status, 0, 0, 5000);
  #|     if (Atomics.load(status, 0) === 1) return true;
  #|     worker.terminate();
  #|   } catch { if (worker) worker.terminate(); }
  #|   delete globalThis[key];
  #|   return false;
  #| }

///|
pub fn start(port : Int, root : String) -> Bool {
  serve_control_js("start", port, root)
}

///|
pub fn broadcast_reload() -> Unit {
  ignore(serve_control_js("reload", 0, ""))
}

///|
pub fn stop() -> Unit {
  ignore(serve_control_js("stop", 0, ""))
}

///|
pub fn is_running() -> Bool {
  serve_control_js("running", 0, "")
}
