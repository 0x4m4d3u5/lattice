import { buildCatalogue } from './catalogue.js';

const form = document.querySelector('#lattice-search');
const controls = document.querySelector('#lattice-controls');
const query = document.querySelector('#lattice-query');
const tags = document.querySelector('#lattice-tags');
const filters = document.querySelector('#lattice-filters');
const clearTags = document.querySelector('#lattice-clear-tags');
const status = document.querySelector('#lattice-status');
const results = document.querySelector('#lattice-results');
const retry = document.querySelector('#lattice-retry');
const navigation = document.querySelector('#lattice-navigation');
const toggle = document.querySelector('#lattice-navigation-toggle');
const catalogueStatus = document.querySelector('#lattice-catalogue-status');
const overview = document.querySelector('.overview-link');
const stateKey = `lattice-reader:${new URL(form.dataset.index, document.baseURI).href}`;
let saved = {};
try { saved = JSON.parse(sessionStorage.getItem(stateKey)) || {}; } catch { /* Storage is optional. */ }
query.value = typeof saved.query === 'string' ? saved.query : '';
let groupState = saved.groups && typeof saved.groups === 'object' ? saved.groups : {};
let catalogueLoaded = false;

// Match the worker and retrieval core's ASCII-only tag identity.
const tagKey = tag => tag.replace(/[A-Z]/g, letter => letter.toLowerCase());

function updateFilters() {
  const count = tags.querySelectorAll('input:checked').length;
  filters.querySelector('summary').textContent = count ? `Filter by tags (${count} selected)` : 'Filter by tags';
  clearTags.hidden = count === 0;
}

function persist() {
  const selected = controls.disabled && !tags.children.length && Array.isArray(saved.tags)
    ? saved.tags : [...tags.querySelectorAll('input:checked')].map(input => input.value);
  try { sessionStorage.setItem(stateKey, JSON.stringify({ query: query.value, tags: selected, groups: groupState })); } catch { /* Private/restricted storage must not break reading. */ }
}
let readingPosition;
function setNavigation(open, restorePosition = true) {
  if (open && !document.body.classList.contains('navigation-open')) {
    readingPosition = { left: scrollX, top: scrollY };
  }
  document.body.classList.toggle('navigation-open', open);
  toggle.setAttribute('aria-expanded', String(open));
  if (!open) {
    // Hiding the article and focusing the menu can move the document scroll.
    if (restorePosition && readingPosition) window.scrollTo({ ...readingPosition, behavior: 'instant' });
    readingPosition = undefined;
  }
}
document.body.classList.add('js');
toggle.hidden = false;
toggle.addEventListener('click', () => {
  syncNavigationLayout();
  const open = toggle.getAttribute('aria-expanded') !== 'true';
  setNavigation(open);
  if (open) overview.focus();
});
navigation.addEventListener('keydown', event => {
  if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
    setNavigation(false); toggle.focus({ preventScroll: true });
  }
});
document.querySelector('.skip').addEventListener('click', () => setNavigation(false, false));
const mobileLayout = window.matchMedia('(max-width: 800px)');
let currentMobileLayout = mobileLayout.matches;
function keepNavigationFocusVisible(focused) {
  if (mobileLayout.matches && navigation.contains(focused)) toggle.focus({ preventScroll: true });
  else if (!mobileLayout.matches && focused === toggle) overview.focus({ preventScroll: true });
}
// Browsers may blur a newly hidden control before dispatching the media change.
for (const region of [navigation, toggle]) region.addEventListener('focusout', event => {
  if (!event.relatedTarget && !region.getClientRects().length) {
    syncNavigationLayout();
    keepNavigationFocusVisible(event.target);
  }
});
function syncNavigationLayout() {
  // Focus recovery or activation may precede a queued media-change event.
  if (currentMobileLayout === mobileLayout.matches) return;
  currentMobileLayout = mobileLayout.matches;
  const focused = document.activeElement;
  // A changed layout invalidates the mobile menu's saved scroll position.
  setNavigation(false, false);
  keepNavigationFocusVisible(focused);
}
mobileLayout.addEventListener('change', syncNavigationLayout);
if (new URL(overview.href).pathname === location.pathname) overview.setAttribute('aria-current', 'page');

function renderCatalogue(entries) {
  const pages = buildCatalogue(entries, document.baseURI, overview.href);
  const groups = new Map();
  for (const page of pages) {
    if (!groups.has(page.collection)) groups.set(page.collection, []);
    groups.get(page.collection).push(page);
  }
  catalogueLoaded = true;
  const directory = document.querySelector('#lattice-page-navigation');
  const collections = document.querySelector('#lattice-collections');
  directory.replaceChildren();
  collections?.replaceChildren();
  for (const [name, pages] of groups) {
    const detail = document.createElement('details');
    detail.open = groupState[name] !== false;
    if (pages.some(page => new URL(page.url).pathname === location.pathname)) detail.open = true;
    const summary = document.createElement('summary');
    summary.textContent = `${name} · ${pages.length}`;
    detail.append(summary);
    const list = document.createElement('ul');
    const section = document.createElement('section');
    section.className = 'collection';
    const heading = document.createElement('div');
    heading.className = 'collection-heading';
    const title = document.createElement('h2'); title.textContent = name;
    const count = document.createElement('span'); count.textContent = `${pages.length} ${pages.length === 1 ? 'note' : 'notes'}`;
    heading.append(title, count); section.append(heading);
    const cards = document.createElement('ul');
    for (const page of pages) {
      const link = document.createElement('a'); link.href = page.url; link.textContent = page.title;
      const item = document.createElement('li'); item.append(link); list.append(item);
      if (new URL(page.url).pathname === location.pathname) {
        link.setAttribute('aria-current', 'page');
        const label = document.querySelector('#lattice-current-collection'); if (label) label.textContent = name;
        const heading = document.querySelector('article > header > h1'); if (heading) heading.textContent = page.title;
      }
      const card = document.createElement('li'); card.append(link.cloneNode(true));
      if (page.description) { const text = document.createElement('p'); text.textContent = page.description; card.append(text); }
      cards.append(card);
    }
    detail.append(list); directory.append(detail);
    detail.addEventListener('toggle', () => { groupState[name] = detail.open; persist(); });
    section.append(cards); collections?.append(section);
  }
  if (catalogueStatus) catalogueStatus.textContent = pages.length ? `${pages.length} published notes · ${groups.size} ${groups.size === 1 ? 'collection' : 'collections'}` : 'No readable pages are listed in this wiki yet.';
}

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
  if (catalogueStatus && !catalogueLoaded) catalogueStatus.textContent = 'The page directory is unavailable. Retry loading the wiki using the navigation panel.';
  retry.hidden = false;
  retry.removeAttribute('aria-disabled');
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
  // Keep an activated retry focusable while loading; native disabled would blur it.
  retry.setAttribute('aria-disabled', 'true');
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
      if (data.type === 'catalogue') { renderCatalogue(data.entries); return; }
      clearTimeout(timer);
      results.setAttribute('aria-busy', 'false');
      try {
        if (data.type === 'ready') {
          const selectedValues = tags.children.length ? [...tags.querySelectorAll('input:checked')].map(input => input.value) : Array.isArray(saved.tags) ? saved.tags : [];
          const selected = new Set(selectedValues.filter(tag => typeof tag === 'string').map(tagKey));
          tags.replaceChildren();
          for (const tag of data.tags) {
            const label = document.createElement('label');
            const input = document.createElement('input');
            input.type = 'checkbox';
            input.value = tag;
            input.checked = selected.has(tagKey(tag));
            label.append(input, document.createTextNode(` ${tag}`));
            tags.append(label);
          }
          filters.hidden = !data.tags.length;
          updateFilters();
          controls.disabled = false;
          if (document.activeElement === retry) query.focus({ preventScroll: true });
          retry.hidden = true;
          retry.removeAttribute('aria-disabled');
          status.textContent = 'Enter a query to search this wiki.';
          if (query.value.trim()) form.requestSubmit();
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
  persist();
  status.textContent = 'Searching…';
  send('search', { query: query.value, tags: [...tags.querySelectorAll('input:checked')].map(input => input.value) });
});
retry.addEventListener('click', () => {
  if (retry.getAttribute('aria-disabled') !== 'true') start();
});
tags.addEventListener('change', () => { updateFilters(); persist(); });
clearTags.addEventListener('click', () => {
  for (const input of tags.querySelectorAll('input:checked')) input.checked = false;
  updateFilters();
  persist();
  query.focus();
  form.requestSubmit();
});
window.addEventListener('pagehide', () => { persist(); stop(); });
window.addEventListener('pageshow', event => { if (event.persisted) start(); });
start();
