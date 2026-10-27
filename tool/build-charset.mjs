/**
 * Produces the character-set baseline for the library: the 3500 level-1
 * characters of 《通用规范汉字表》 (State Council, 国发〔2013〕23号).
 *
 * The Ministry of Education states that the level-1 table "也可以作为义务教育
 * 阶段的识字标准" — it is the official literacy standard, and it is a superset
 * of the 3000 characters the primary-school curriculum requires.
 *
 * The list is derived from the GF 0023-2020 extraction (`official-strokes.json`),
 * which carries each character's 字表序号. Level 1 is simply 序号 1–3500.
 *
 * Usage:
 *   node tool/extract_official_strokes.mjs   # once, to build the cache
 *   node tool/build-charset.mjs
 *
 * Output: tool/data/level1.json
 *   { "<char>": { "index": 1, "strokes": 1, "codes": "1" }, ... }
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(HERE, '..');
const SRC = path.join(HERE, '.cache', 'official-strokes.json');
const OUT = path.join(HERE, 'data', 'level1.json');

if (!fs.existsSync(SRC)) {
  console.error('缺少官方笔顺数据，请先运行：node tool/extract_official_strokes.mjs');
  process.exit(2);
}

const official = JSON.parse(fs.readFileSync(SRC, 'utf8'));

/**
 * Level-1 characters that the primary-school writing lists also require.
 *
 * The textbook writing lists are not a strict subset of the level-1 table:
 * these ten are level-2 characters that the volumes still teach, so the library
 * has to carry them or ten characters would be unreachable.
 */
const TEXTBOOK_EXTRA = [...'珑蚱仞桅艄眺诣咆藓皎'];

const level1 = Object.values(official)
  .filter((r) => r.index <= 3500)
  .sort((a, b) => a.index - b.index);

for (const char of TEXTBOOK_EXTRA) {
  const r = official[char];
  if (!r) { console.error('教材补充字缺少官方数据：' + char); process.exit(2); }
  if (r.index <= 3500) { console.error('教材补充字已在一级字内：' + char); process.exit(2); }
  level1.push({ ...r, textbookExtra: true });
}

const out = Object.fromEntries(level1.map((r) => [r.char, r]));

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out));

// Report how this relates to what the app already ships.
const catalogPath = path.join(ROOT, 'assets', 'data', 'catalog.json');
let have = new Set();
if (fs.existsSync(catalogPath)) {
  have = new Set(JSON.parse(fs.readFileSync(catalogPath, 'utf8')).map((e) => e.char));
}
const missing = level1.filter((r) => !have.has(r.char));

console.log(`一级字表条目      ${level1.length}`);
console.log(`  其中国标一级字  ${level1.length - TEXTBOOK_EXTRA.length}`);
console.log(`  教材补充字      ${TEXTBOOK_EXTRA.length}（${TEXTBOOK_EXTRA.join('')}）`);
console.log(`序号范围          ${level1[0].index} … ${Math.max(...level1.map((r) => r.index))}`);
console.log(`现有字库          ${have.size} 字`);
console.log(`其中属一级字      ${level1.length - missing.length}`);
console.log(`需新增            ${missing.length} 字`);
console.log(`写入              ${path.relative(ROOT, OUT)}`);
