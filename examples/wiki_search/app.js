const form = document.querySelector('#search');
const controls = document.querySelector('#controls');
const query = document.querySelector('#query');
const tags = document.querySelector('#tags');
const status = document.querySelector('#status');
const results = document.querySelector('#results');
const retry = document.querySelector('#retry');
let activeWorker;
let request = 0;
let timer;

function stop() {
  clearTimeout(timer);
  activeWorker?.terminate();
  activeWorker = undefined;
}

function fail() {
  stop();
  controls.disabled = true;
  results.replaceChildren();
  results.setAttribute('aria-busy', 'false');
  status.textContent = 'Search is unavailable. Retry loading search.';
  retry.hidden = false;
}

function send(type, payload) {
  clearTimeout(timer);
  const id = ++request;
  results.setAttribute('aria-busy', 'true');
  timer = setTimeout(fail, 30_000);
  try { activeWorker.postMessage({ id, type, ...payload }); }
  catch { fail(); }
}

function renderHits(hits) {
  results.replaceChildren();
  for (const hit of hits) {
    const item = document.createElement('li');
    const heading = document.createElement('h2');
    const title = document.createElement('a');
    // The retrieval core copies caller-supplied URLs. Only web URLs navigate.
    try {
      const url = new URL(hit.url, document.baseURI);
      if (url.protocol === 'https:' || url.protocol === 'http:') {
        title.setAttribute('href', hit.url);
      }
    } catch { /* Invalid citations remain text, without disabling other hits. */ }
    title.textContent = hit.title;
    heading.append(title);
    item.append(heading);
    for (const [name, text] of [
      ['section', hit.section || 'Introduction'],
      ['snippet', hit.snippet],
      ['citation', hit.url],
    ]) {
      const paragraph = document.createElement('p');
      paragraph.className = name;
      paragraph.textContent = text;
      item.append(paragraph);
    }
    results.append(item);
  }
  status.textContent = hits.length ? `Showing ${hits.length} matching sections (up to 10).` : 'No matching sections.';
}

function start() {
  stop();
  retry.hidden = true;
  controls.disabled = true;
  results.replaceChildren();
  status.textContent = 'Loading search…';
  try {
    const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
    activeWorker = worker;
    for (const type of ['error', 'messageerror']) {
      worker.addEventListener(type, event => {
        event.preventDefault();
        if (worker === activeWorker) fail();
      });
    }
    worker.addEventListener('message', ({ data }) => {
      if (worker !== activeWorker || data.id !== request) return;
      clearTimeout(timer);
      results.setAttribute('aria-busy', 'false');
      try {
        if (data.type === 'ready') {
          const selected = new Set([...tags.querySelectorAll('input:checked')].map(input => input.value));
          tags.replaceChildren();
          for (const tag of data.tags) {
            const label = document.createElement('label');
            const input = document.createElement('input');
            input.type = 'checkbox';
            input.value = tag;
            input.checked = selected.has(tag);
            label.append(input, document.createTextNode(` ${tag}`));
            tags.append(label);
          }
          document.querySelector('#filters').hidden = !data.tags.length;
          controls.disabled = false;
          status.textContent = 'Enter a query to search this wiki.';
        } else if (data.type === 'results') {
          renderHits(data.results);
        } else {
          fail();
        }
      } catch { fail(); }
    });
    send('load', { indexUrl: new URL(form.dataset.index, document.baseURI).href });
  } catch { fail(); }
}

form.addEventListener('submit', event => {
  event.preventDefault();
  if (controls.disabled) return;
  results.replaceChildren();
  if (!query.value.trim()) {
    ++request; // Clearing invalidates any pending result, too.
    clearTimeout(timer);
    results.setAttribute('aria-busy', 'false');
    status.textContent = 'Enter a query to search this wiki.';
    return;
  }
  status.textContent = 'Searching…';
  send('search', { query: query.value, tags: [...tags.querySelectorAll('input:checked')].map(input => input.value) });
});
retry.addEventListener('click', start);
window.addEventListener('pagehide', stop);
window.addEventListener('pageshow', event => { if (event.persisted) start(); });
start();
