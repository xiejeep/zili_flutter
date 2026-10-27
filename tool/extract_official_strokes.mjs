/**
 * Extracts the official stroke order table from GF 0023-2020
 * 《通用规范汉字笔顺规范》(Ministry of Education / State Language Commission).
 *
 * The source PDF is a text PDF using CID fonts *without* a ToUnicode map, so a
 * naive byte scan yields nothing. pdf.js recovers the characters by walking the
 * embedded font's own cmap, which is why this script depends on it.
 *
 * The table is two columns wide, and each row is stacked vertically:
 *
 *       2 1 2 1 2 5 1        <- stroke digits, wrapping to a second line when
 *       肯                    <- character       the row has more than 7 strokes
 *       1067  080AF          <- 字表序号, UCS code point
 *       8 画                  <- stroke count
 *       1                    <- stroke digits, continued
 *
 * So reading order cannot be trusted. Rows are located by their 序号 + UCS pair
 * and digits are gathered from the row's vertical band instead.
 *
 * Stroke digits follow the standard's five categories:
 *   1 横 (incl. 提)   2 竖 (incl. 竖钩)   3 撇   4 点 (incl. 捺)   5 折 (all compound)
 *
 * Usage:
 *   node tool/extract_official_strokes.mjs [path-to-pdf]
 *
 * Output: tool/.cache/official-strokes.json
 *   { "<char>": { "strokes": 7, "codes": "3235534", "index": 123, "ucs": "04F60" }, ... }
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(HERE, '..');
const PDF = process.argv[2] || '/tmp/bishun.pdf';
const OUT = path.join(HERE, '.cache', 'official-strokes.json');

// pdf.js lives in the isolated managed workspace, not in this project.
const PDFJS_ROOT = '/Users/jmspay/.workbuddy/binaries/node/workspace/node_modules/pdfjs-dist';

if (!fs.existsSync(PDF)) {
  console.error('找不到源 PDF：' + PDF);
  console.error('请先从教育部官网下载《通用规范汉字笔顺规范》(GF 0023-2020)：');
  console.error('  https://hudong.moe.gov.cn/jyb_sjzl/ziliao/A19/202103/W020210318300204215237.pdf');
  process.exit(1);
}

const pdfjs = await import(path.join(PDFJS_ROOT, 'legacy/build/pdf.mjs'));

const doc = await pdfjs.getDocument({
  data: new Uint8Array(fs.readFileSync(PDF)),
  cMapUrl: path.join(PDFJS_ROOT, 'cmaps/'),
  cMapPacked: true,
  standardFontDataUrl: path.join(PDFJS_ROOT, 'standard_fonts/'),
  isEvalSupported: false,
  useSystemFonts: false,
}).promise;

// CJK ideographs, including the astral planes (CJK Ext B and up).
const CJK = /^[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u{20000}-\u{3ffff}]\ufe00?$/u;
// The UCS cell holds the code point in hex, zero padded to five digits — but
// astral characters need six, and then the leading digit is not a zero. Anchors
// must be found for those rows too, otherwise the banding around their
// neighbours stretches into the wrong row.
const UCS = /^[0-9A-F]{5,6}$/;
const INDEX = /^\d{4}$/;
const COUNT = /^(\d{1,2})画$/;
const DIGIT = /^[1-5]$/;
const COLUMN_SPLIT = 268;   // x boundary between the two table columns
// The character cell sits at a fixed x in each column; the stroke column to its
// right also holds CJK glyphs (the shape of each stroke), so the x window keeps
// them apart.
const CHAR_X = [[45, 85], [258, 300]];

const rows = [];
const problems = [];
let digitPool = 0;

process.stdout.write(`解析 ${doc.numPages} 页`);

for (let p = 1; p <= doc.numPages; p++) {
  const page = await doc.getPage(p);
  const content = await page.getTextContent();

  const items = content.items
    .map((i) => ({ s: i.str.replace(/\s+/g, ''), x: i.transform[4], y: i.transform[5] }))
    .filter((o) => o.s);

  // Drop the running header so its "0023"/"2020" cannot be mistaken for data.
  const header = items.filter((o) => o.s.includes('GF0023'));
  const top = header.length ? Math.max(...header.map((o) => o.y)) : Infinity;

  const body = items.filter((o) => o.y < top - 2);

  // A row anchor is a 4-digit index immediately followed by a UCS code point.
  const anchors = [];
  for (const a of body) {
    if (!INDEX.test(a.s)) continue;
    const u = body.find(
      (o) => UCS.test(o.s) && Math.abs(o.y - a.y) < 2 && o.x > a.x && o.x - a.x < 40,
    );
    if (u) anchors.push({ index: Number(a.s), ucs: u.s, x: a.x, y: a.y });
  }
  if (!anchors.length) continue;

  // Split into the two table columns, then derive each row's vertical band from
  // the midpoints to its neighbours. Row spacing varies (dense short rows on the
  // low stroke-count pages are only ~45pt apart), so a fixed band would bleed
  // into the next row.
  for (const col of [0, 1]) {
    const column = anchors
      .filter((a) => (a.x < COLUMN_SPLIT ? 0 : 1) === col)
      .sort((a, b) => b.y - a.y);

    for (let i = 0; i < column.length; i++) {
      const anchor = column[i];
      const above = column[i - 1];
      const below = column[i + 1];
      const top = above ? (anchor.y + above.y) / 2 : anchor.y + 45;
      const bottom = below ? (anchor.y + below.y) / 2 : anchor.y - 45;
      const inBand = (o) => o.y <= top && o.y > bottom;
      const [x0, x1] = CHAR_X[col];
      const sameCol = (o) => (o.x < COLUMN_SPLIT ? 0 : 1) === col;

      // The character sits just above the anchor, inside its own x window.
      let char = null;
      let best = Infinity;
      for (const o of body) {
        if (!CJK.test(o.s) || o.x < x0 || o.x > x1) continue;
        const d = Math.abs(o.y - anchor.y);
        if (d < best) { best = d; char = o.s; }
      }

      // The stroke count sits just below.
      let strokes = null;
      best = Infinity;
      for (const o of body) {
        const m = COUNT.exec(o.s);
        if (!m || !sameCol(o) || !inBand(o)) continue;
        const d = Math.abs(o.y - anchor.y);
        if (d < best) { best = d; strokes = Number(m[1]); }
      }

      // Stroke digits: single 1-5 glyphs in the band, read top-down then
      // left-right. Very high stroke counts (22+) wrap the cell onto a fourth
      // line that can fall past the midpoint to the next row, so the band is
      // widened in small steps until the count matches exactly. Overshooting is
      // rejected rather than accepted, so a bad widening cannot slip through.
      let digits = '';
      for (const extra of [0, 6, 12, 18, 24]) {
        digits = body
          .filter((o) => DIGIT.test(o.s) && sameCol(o) && o.y <= top && o.y > bottom - extra)
          .sort((a, b) => b.y - a.y || a.x - b.x)
          .map((o) => o.s)
          .join('');
        if (digits.length >= strokes) break;
      }
      digitPool += digits.length;

      if (!char || strokes === null) {
        problems.push(`p${p} 序号${anchor.index} 缺少${char ? '笔画数' : '汉字'}`);
        continue;
      }
      if (digits.length !== strokes) {
        problems.push(`p${p} ${char} 笔顺位数 ${digits.length} ≠ 笔画数 ${strokes}`);
        continue;
      }

      rows.push({ char, strokes, codes: digits, index: anchor.index, ucs: anchor.ucs });
    }
  }

  if (p % 40 === 0) process.stdout.write(`.${p}`);
}

process.stdout.write('\n');

// Deduplicate by index and by character, keeping the first occurrence.
const byIndex = new Map();
for (const r of rows) if (!byIndex.has(r.index)) byIndex.set(r.index, r);

const list = [...byIndex.values()].sort((a, b) => a.index - b.index);
const out = {};
for (const r of list) if (!out[r.char]) out[r.char] = r;

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out));

console.log(`提取条目: ${Object.keys(out).length}  (去重前 ${rows.length})`);
console.log(`序号范围: ${list.length ? list[0].index : '-'} … ${list.length ? list[list.length - 1].index : '-'}`);
console.log(`笔顺数字总数: ${digitPool}`);
console.log(`问题行: ${problems.length}`);
if (problems.length) console.log('  ' + problems.slice(0, 12).join('\n  '));
console.log(`写入: ${path.relative(ROOT, OUT)}`);
