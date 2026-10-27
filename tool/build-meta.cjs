/**
 * Builds the glyph-level metadata for every level-1 character.
 *
 * Everything here is derivable without any hand-written content, so it can be
 * regenerated at will:
 *
 *   - 拼音 (with 声韵调 split)  from Unicode Unihan kMandarin, which measured
 *                               best against the hand-checked readings (97.8%);
 *                               the open dictionary and the `pinyin` package are
 *                               used only when Unihan has nothing
 *   - 部首 / 结构 / 部首名        from cnchar, with a small verified fallback for
 *                               the 21 characters cnchar lacks
 *   - 笔画名 (30 detailed names) resolved from cnchar letters, see lib/stroke-names
 *   - 笔画路径 + 中线            from Hanzi Writer Data, packed by lib/stroke-codec
 *
 * Meaning, words and example sentences are NOT here — those are hand/AI written
 * and live in tool/content/*.tsv.
 *
 * Usage:
 *   node tool/build-meta.cjs
 *
 * Output: tool/build/meta.json
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const ROOT = path.resolve(__dirname, '..');
const NODE_MODULES = '/Users/jmspay/.workbuddy/binaries/node/workspace/node_modules';
const HANZI_DATA = path.join(NODE_MODULES, 'hanzi-writer-data');
const OUT = path.join(__dirname, 'build', 'meta.json');

const codec = require('./lib/stroke-codec.cjs');
const { resolveNames } = require('./lib/stroke-names.cjs');

/* ---------- cnchar (radical, structure, stroke order) ---------- */
const ctx = { console, setTimeout, clearTimeout };
ctx.window = ctx; ctx.self = ctx; ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(NODE_MODULES, 'cnchar/cnchar.min.js'), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(path.join(NODE_MODULES, 'cnchar-order/cnchar.order.min.js'), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(path.join(NODE_MODULES, 'cnchar-radical/cnchar.radical.min.js'), 'utf8'), ctx);
const cnchar = ctx.cnchar;
cnchar.use(ctx.CncharOrder);
cnchar.use(ctx.CncharRadical);
const orders = cnchar.order.dict.orders;

/* ---------- pinyin ---------- */
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

/** Unicode Unihan kMandarin — the primary source. */
const unihan = JSON.parse(fs.readFileSync(path.join(__dirname, '.cache', 'unihan-mandarin.json'), 'utf8'));

/** The open dictionary, keyed by character; its first reading is the common one. */
const dictPinyin = {};
const dictFile = path.join(__dirname, '.cache', 'char_base.json');
if (fs.existsSync(dictFile)) {
  const raw = fs.readFileSync(dictFile, 'utf8').trim().replace(/,$/, '');
  for (const e of JSON.parse('[' + raw + ']')) {
    if (e.char && e.pinyin && e.pinyin.length) dictPinyin[e.char] = e.pinyin[0];
  }
}

/** Normalises the odd glyphs some sources use (ŋ U+014B, ɡ U+0261) and drops tone digits. */
const normalise = (p) => String(p || '')
  .replace(/ŋ/g, 'ng').replace(/ɡ/g, 'g').replace(/\d/g, '').trim();

/* ---------- 部首 / 结构 ---------- */
const radicalNames = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'radical-names.json'), 'utf8'));
const STRUCT_ALIAS = { '独体结构': '独体字' };

/**
 * cnchar's radical table has no entry for these 21 characters. Radicals come
 * from Hanzi Writer's dictionary; structures were checked by hand against each
 * character's 部件拆分.
 */
const RADICAL_FALLBACK = {
  刀: '刀', 叉: '又', 仇: '亻', 币: '巾', 死: '歹', 杀: '木', 枪: '木',
  刺: '刂', 毒: '母', 钞: '钅', 剑: '刂', 炸: '火', 炮: '火', 淫: '氵',
  弹: '弓', 棒: '木', 棍: '木', 硝: '石', 赌: '贝', 箭: '竹', 爆: '火',
};
const STRUCT_FALLBACK = {
  刀: '独体字', 叉: '独体字', 仇: '左右结构', 币: '上下结构', 死: '左右结构',
  杀: '上下结构', 枪: '左右结构', 刺: '左右结构', 毒: '上下结构', 钞: '左右结构',
  剑: '左右结构', 炸: '左右结构', 炮: '左右结构', 淫: '左右结构', 弹: '左右结构',
  棒: '左右结构', 棍: '左右结构', 硝: '左右结构', 赌: '左右结构', 箭: '上下结构',
  爆: '左右结构',
};

function radicalOf(char) {
  const hit = (cnchar.radical(char) || [])[0];
  return (hit && hit.radical) || RADICAL_FALLBACK[char] || '';
}
function structureOf(char) {
  const hit = (cnchar.radical(char) || [])[0];
  if (hit && hit.struct) return STRUCT_ALIAS[hit.struct] || hit.struct;
  return STRUCT_FALLBACK[char] || '';
}
function radicalNameOf(char, radical, structure) {
  if (radicalNames[radical]) return radicalNames[radical];
  if (!radical) return '';
  if (structure === '独体字') return radical + '部';
  if (/^(上下结构|上中下结构)$/.test(structure)) {
    return char.startsWith(radical) ? radical + '字头' : radical + '字底';
  }
  return radical + '字旁';
}

/* ---------- 笔画名 -> base36 码 ---------- */
const CODE_CHARS = '0123456789abcdefghijklmnopqrstuvwxyz';
const nameList = [];
const nameCode = new Map();
const pushName = (n) => { if (!nameCode.has(n)) { nameCode.set(n, nameList.length); nameList.push(n); } };

/* ---------- 部件拆分（用于横斜钩） ---------- */
const decompositions = {};
const mmah = path.join(__dirname, '.cache', 'dictionary.txt');
if (fs.existsSync(mmah)) {
  for (const line of fs.readFileSync(mmah, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    const o = JSON.parse(line);
    decompositions[o.character] = o.decomposition || '';
  }
}

/* ---------- build ---------- */
const level1 = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'level1.json'), 'utf8'));
const chars = Object.keys(level1);

const meta = {};
const problems = [];
const pinyinFrom = { unihan: 0, dict: 0, package: 0 };
let packedBytes = 0;

for (const char of chars) {
  const strokeFile = path.join(HANZI_DATA, char + '.json');
  if (!fs.existsSync(strokeFile)) { problems.push(char + ' 缺笔画数据'); continue; }
  const raw = JSON.parse(fs.readFileSync(strokeFile, 'utf8'));

  const letters = orders[char];
  if (!letters) { problems.push(char + ' 缺笔顺'); continue; }
  if (letters.length !== raw.strokes.length) {
    problems.push(`${char} 笔顺位数 ${letters.length} ≠ 笔画数 ${raw.strokes.length}`);
    continue;
  }

  const names = resolveNames(char, letters, raw.medians, decompositions[char]);
  if (names.some((n) => !n)) { problems.push(char + ' 笔画名有空值'); continue; }
  names.forEach(pushName);

  // Pinyin, in order of measured reliability.
  const readings = unihan[char] || [];
  let syllable = normalise(readings[0]);
  if (syllable) pinyinFrom.unihan++;
  else if (dictPinyin[char]) { syllable = normalise(dictPinyin[char]); pinyinFrom.dict++; }
  else {
    const guess = pinyin(char, { style: pinyinLib.STYLE_TONE })[0];
    syllable = guess ? normalise(guess[0]) : '';
    if (syllable) pinyinFrom.package++;
  }
  if (!syllable) { problems.push(char + ' 无拼音'); continue; }

  const py = splitSyllable(syllable);
  const radical = radicalOf(char);
  const structure = structureOf(char);
  if (!radical) problems.push(char + ' 缺部首');
  if (!structure) problems.push(char + ' 缺结构');

  const packed = codec.encode(raw);
  packedBytes += packed.length;

  meta[char] = {
    pinyin: syllable,
    plain: py.plain,
    initial: py.initial,
    final: py.final,
    tone: py.tone,
    syllable: py.plain + py.tone + '.m4a',
    readings: readings.map(normalise).filter(Boolean),
    radical,
    radicalName: radicalNameOf(char, radical, structure),
    structure,
    strokeCodes: names.map((n) => CODE_CHARS[nameCode.get(n)]).join(''),
    strokeNames: names,
    strokes: raw.strokes.length,
    packed,
  };
}

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(meta));

/* ---------- report ---------- */
const syllables = new Set(Object.values(meta).map((m) => m.syllable));
const polyphones = Object.values(meta).filter((m) => m.readings.length > 1).length;
console.log('字符数        %d / %d', Object.keys(meta).length, chars.length);
console.log('笔画名种类    %d', nameList.length);
console.log('单字音节      %d', syllables.size);
console.log('多音字        %d', polyphones);
console.log('拼音来源      Unihan %d / 词典 %d / pinyin 包 %d',
  pinyinFrom.unihan, pinyinFrom.dict, pinyinFrom.package);
console.log('笔画数据      %s KB', (packedBytes / 1024).toFixed(0));
console.log('问题          %d', problems.length);
if (problems.length) console.log('  %s', problems.slice(0, 15).join('\n  '));
console.log('写入          %s', path.relative(ROOT, OUT));
