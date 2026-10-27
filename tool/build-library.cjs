/**
 * Merges the glyph metadata with the hand/AI written content and writes the
 * files the Flutter app loads.
 *
 * Inputs:
 *   tool/build/meta.json     字形元信息（tool/build-meta.cjs 生成）
 *   tool/content/*.tsv       释义/组词/例句，格式 字|拼音|释义|组词1|组词2|例句
 *   tool/data/books/*.json   教材册次结构
 * Outputs:
 *   assets/data/catalog.json        每字一条完整记录
 *   assets/data/strokes.json        压缩后的笔画路径
 *   assets/data/stroke_names.json   笔画名表
 *   assets/data/stroke_codes.json   笔画名的 base36 字母表
 *   assets/data/curriculum.json     教材册次
 *   tool/build/syllables.txt        需要合成的音节清单（供 build-audio 使用）
 *
 * Usage:
 *   node tool/build-library.cjs [--require-content]
 *
 * Without --require-content a character with no written content is skipped with
 * a warning, which is what you want while content is still being written.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const NODE_MODULES = '/Users/jmspay/.workbuddy/binaries/node/workspace/node_modules';
const META = path.join(__dirname, 'build', 'meta.json');
const OUT_DIR = path.join(ROOT, 'assets', 'data');
const REQUIRE_CONTENT = process.argv.includes('--require-content');

const pinyinLib = require(path.join(NODE_MODULES, 'pinyin'));
const pinyin = pinyinLib.default || pinyinLib;

const TONE_MAP = {
  'ā': ['a', 1], 'á': ['a', 2], 'ǎ': ['a', 3], 'à': ['a', 4],
  'ē': ['e', 1], 'é': ['e', 2], 'ě': ['e', 3], 'è': ['e', 4],
  'ī': ['i', 1], 'í': ['i', 2], 'ǐ': ['i', 3], 'ì': ['i', 4],
  'ō': ['o', 1], 'ó': ['o', 2], 'ǒ': ['o', 3], 'ò': ['o', 4],
  'ū': ['u', 1], 'ú': ['u', 2], 'ǔ': ['u', 3], 'ù': ['u', 4],
  'ǖ': ['v', 1], 'ǘ': ['v', 2], 'ǚ': ['v', 3], 'ǜ': ['v', 4], 'ü': ['v', 5],
};

const INITIALS = ['zh', 'ch', 'sh', 'b', 'p', 'm', 'f', 'd', 't', 'n', 'l',
  'g', 'k', 'h', 'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w'];

function splitSyllable(syllable) {
  let plain = '';
  let tone = 5;
  for (const ch of syllable) {
    const hit = TONE_MAP[ch];
    if (hit) { plain += hit[0]; tone = hit[1]; } else plain += ch;
  }
  let initial = '';
  for (const c of INITIALS) if (plain.startsWith(c)) { initial = c; break; }
  return { plain, tone, initial, final: syllable.slice(initial.length) || syllable };
}
const audioName = (syllable) => {
  const s = splitSyllable(syllable);
  return s.plain + s.tone + '.m4a';
};
const normalize = (text) => String(text || '').trim()
  .replace(/,/g, '，').replace(/;/g, '；').replace(/!/g, '！')
  .replace(/\?/g, '？').replace(/\s+/g, '');

/* ---------- inputs ---------- */
const meta = JSON.parse(fs.readFileSync(META, 'utf8'));

const content = new Map();
const contentDir = path.join(__dirname, 'content');
const contentFiles = fs.readdirSync(contentDir).filter((f) => f.endsWith('.tsv')).sort();
for (const file of contentFiles) {
  for (const row of fs.readFileSync(path.join(contentDir, file), 'utf8').trim().split('\n')) {
    if (!row.trim()) continue;
    const cells = row.split('|');
    if (cells.length < 6) throw new Error(`${file} 内容行字段不足: ${row}`);
    content.set(cells[0], {
      pinyin: cells[1].trim(),
      meaning: normalize(cells[2]),
      words: [normalize(cells[3]), normalize(cells[4])],
      sentence: normalize(cells[5]),
    });
  }
}

const bookDir = path.join(__dirname, 'data', 'books');
const bookFiles = fs.existsSync(bookDir)
  ? fs.readdirSync(bookDir).filter((f) => f.endsWith('.json')).sort()
  : [];

/* ---------- build ---------- */
const CODE_CHARS = '0123456789abcdefghijklmnopqrstuvwxyz';
const entries = [];
const strokesPayload = {};
const syllables = new Map();   // audio file -> a character read that way
const addSyllable = (name, char) => { if (!syllables.has(name)) syllables.set(name, char); };
const missingContent = [];
const problems = [];

for (const [char, m] of Object.entries(meta)) {
  const info = content.get(char);
  if (!info) { missingContent.push(char); if (REQUIRE_CONTENT) problems.push(char + ' 缺少释义内容'); continue; }

  // The written pinyin wins: it reflects the reading the textbook uses, which
  // for 多音字 can differ from the most common standalone reading.
  const syllableText = info.pinyin || m.pinyin;
  const py = splitSyllable(syllableText);
  const syllable = audioName(syllableText);
  addSyllable(syllable, char);

  const wordSyllables = info.words.map((word) => [...word].map((ch, i) => {
    const r = pinyin(ch, { style: pinyinLib.STYLE_TONE })[0];
    const name = audioName(r ? r[0] : '');
    addSyllable(name, ch);
    return name;
  }));

  entries.push({
    char,
    pinyin: syllableText,
    plain: py.plain,
    radical: m.radical,
    radicalName: m.radicalName,
    structure: m.structure,
    meaning: info.meaning,
    words: info.words,
    wordSyllables,
    sentence: info.sentence,
    initial: py.initial,
    final: py.final,
    tone: py.tone,
    syllable,
    strokeCodes: m.strokeCodes,
    strokes: m.strokes,
  });
  strokesPayload[char] = m.packed;
}

/* ---------- stroke name table ---------- */
const nameList = [];
const seen = new Set();
for (const m of Object.values(meta)) {
  for (const n of m.strokeNames) if (!seen.has(n)) { seen.add(n); nameList.push(n); }
}
if (nameList.length > CODE_CHARS.length) throw new Error('笔画名称种类过多');

/* ---------- outputs ---------- */
fs.mkdirSync(OUT_DIR, { recursive: true });
const write = (name, data) => {
  const file = path.join(OUT_DIR, name);
  fs.writeFileSync(file, JSON.stringify(data), 'utf8');
  console.log('%s %s KB', name.padEnd(22), (fs.statSync(file).size / 1024).toFixed(0));
};

write('catalog.json', entries);
write('strokes.json', strokesPayload);
write('stroke_names.json', nameList);
write('stroke_codes.json', CODE_CHARS);

/* ---------- curriculum ---------- */
const books = bookFiles.map((file) => {
  const list = JSON.parse(fs.readFileSync(path.join(bookDir, file), 'utf8'));
  const chars = [...new Set(list.all)].filter((c) => meta[c]);
  return {
    id: path.basename(file, '.json'),
    title: list.book,
    source: (list.sourceNotes || '').slice(0, 240),
    chars,
    checked: true,
  };
});
// The app expects a plain array of volumes here.
write('curriculum.json', books);

/* ---------- syllable list ---------- */
fs.mkdirSync(path.join(__dirname, 'build'), { recursive: true });
fs.writeFileSync(
  path.join(__dirname, 'build', 'syllables.txt'),
  [...syllables.entries()].sort((a, b) => (a[0] < b[0] ? -1 : 1))
    .map(([name, char]) => `${name}\t${char}`).join('\n') + '\n',
);

/* ---------- report ---------- */
console.log('---');
console.log('字库条目      %d / %d', entries.length, Object.keys(meta).length);
console.log('教材册数      %d', books.length);
console.log('音节（含组词）%d', syllables.size);
console.log('缺内容        %d', missingContent.length);
if (missingContent.length) console.log('  %s', missingContent.slice(0, 40).join(''));
console.log('问题          %d', problems.length);
if (problems.length) console.log('  %s', problems.slice(0, 10).join('\n  '));
if (REQUIRE_CONTENT && problems.length) process.exit(1);
