/**
 * Cross-checks our library's stroke order against the official standard
 * GF 0023-2020 《通用规范汉字笔顺规范》.
 *
 * Our `strokeCodes` field stores one base-36 character per stroke, indexing the
 * 30 detailed stroke names in `strokeNames` (see tool/export_library.cjs).
 * The official table uses the five broad categories instead:
 *
 *   1 横 (incl. 提)   2 竖 (incl. 竖钩)   3 撇   4 点 (incl. 捺)   5 折 (all compound)
 *
 * So our detailed names are folded down to those five before comparing. Run
 * `node tool/extract_official_strokes.mjs` first to produce the reference data.
 *
 * Usage:
 *   node tool/verify-strokes.mjs
 *
 * Exits non-zero when any character disagrees, so it can gate a build.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(HERE, '..');
const OFFICIAL = path.join(HERE, '.cache', 'official-strokes.json');
const CATALOG = path.join(ROOT, 'assets', 'data', 'catalog.json');

if (!fs.existsSync(OFFICIAL)) {
  console.error('缺少官方笔顺数据，请先运行：node tool/extract_official_strokes.mjs');
  process.exit(2);
}

// The 30 detailed stroke names and their base-36 alphabet come from the built
// assets, not a hard-coded list: the name table is ordered by first appearance
// so its indices shift whenever the library grows.
const NAMES = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets', 'data', 'stroke_names.json'), 'utf8'));
const CHARS = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets', 'data', 'stroke_codes.json'), 'utf8'));

/** Folds a detailed stroke name down to the official 1-5 category. */
function toOfficial(name) {
  switch (name) {
    case '横': case '提': return '1';
    case '竖': case '竖钩': return '2';
    case '撇': return '3';
    case '点': case '捺': return '4';
    default: return '5';   // every remaining name is a compound, i.e. 折
  }
}

const official = JSON.parse(fs.readFileSync(OFFICIAL, 'utf8'));
const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));

const missing = [];
const mismatches = [];
let checked = 0;

for (const entry of catalog) {
  const ref = official[entry.char];
  if (!ref) { missing.push(entry.char); continue; }

  const mine = [...entry.strokeCodes].map((c) => toOfficial(NAMES[CHARS.indexOf(c)])).join('');
  checked++;

  if (mine !== ref.codes) {
    mismatches.push({ char: entry.char, mine, official: ref.codes });
  }
}

console.log(`字库条目            ${catalog.length}`);
console.log(`官方数据可对照      ${checked}`);
console.log(`官方未收录          ${missing.length}${missing.length ? '  ' + missing.join('') : ''}`);
console.log(`笔顺不一致          ${mismatches.length}`);

if (mismatches.length) {
  console.log('\n逐条明细（我们 vs 官方）：');
  for (const m of mismatches.slice(0, 60)) {
    console.log(`  ${m.char}  我们=${m.mine}  官方=${m.official}`);
  }
  if (mismatches.length > 60) console.log(`  … 另有 ${mismatches.length - 60} 条`);
}

const ok = missing.length === 0 && mismatches.length === 0;
console.log(`\n${ok ? '✅ 全部一致' : '❌ 存在差异'}`);
process.exit(ok ? 0 : 1);
