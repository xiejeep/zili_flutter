/* Exports the mini program library into plain JSON for the Flutter app. */
const fs = require('node:fs');
const path = require('node:path');

const src = path.resolve(__dirname, '../../zili-miniprogram/miniprogram/learn/data');
const out = path.resolve(__dirname, '../assets/data');
fs.mkdirSync(out, { recursive: true });

const catalog = require(path.join(src, 'catalog.js'));
const curriculum = require(path.join(src, 'curriculum.js'));
const codes = require(path.join(src, 'stroke-codes.js'));

// strokes.js pulls in the runtime codec, load it in a sandbox with a stub require.
const vm = require('node:vm');
const sandbox = { module: { exports: {} }, require: () => ({}) };
sandbox.exports = sandbox.module.exports;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(src, 'strokes.js'), 'utf8'), sandbox);
const strokes = sandbox.module.exports;

// Flutter reads plain JSON, keep only the fields the app uses.
const entries = catalog.map(entry => ({
  char: entry.char,
  pinyin: entry.pinyin,
  plain: entry.plain,
  radical: entry.radical,
  radicalName: entry.radicalName,
  structure: entry.structure,
  meaning: entry.meaning,
  words: entry.words,
  wordSyllables: entry.wordSyllables,
  sentence: entry.sentence,
  initial: entry.initial,
  final: entry.final,
  tone: entry.tone,
  syllable: entry.syllable,
  strokeCodes: entry.strokeCodes,
  strokes: entry.strokes
}));

const write = (name, data) => {
  const file = path.join(out, name);
  fs.writeFileSync(file, JSON.stringify(data), 'utf8');
  console.log(name.padEnd(22), (fs.statSync(file).size / 1024).toFixed(0) + 'KB');
};

write('catalog.json', entries);
write('strokes.json', strokes.packed);
write('stroke_names.json', codes.names);
write('stroke_codes.json', codes.chars);
write('curriculum.json', curriculum.books);

console.log('汉字', entries.length, '笔画种类', codes.names.length,
  '教材册数', curriculum.books.length);
