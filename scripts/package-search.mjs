import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { prepareWikiAssets } from './wiki-package.mjs';

if (process.argv.length !== 3) throw new Error('Usage: node scripts/package-search.mjs NEW_DIRECTORY');
const destination = resolve(process.argv[2]);
// Read every input before creating output; never replace an existing directory.
const files = await prepareWikiAssets();
await mkdir(destination);
await Promise.all(files.map(([name, bytes]) => writeFile(join(destination, name), bytes, { flag: 'wx' })));
console.log(`Packaged wiki search in ${destination}`);
