/**
 * Builds the per-volume writing lists from the open textbook character list.
 *
 * Source: zispace/hanzi-chars-ext 的
 * 「中国大陆人民教育出版社《义务教育教科书·语文》（统编版）写字表」
 * https://github.com/zispace/hanzi-chars-ext
 *
 * The file is a plain list of the 2500 writing-list characters in textbook
 * order, with per-volume counts and the first/last character of each volume in
 * its header. Splitting on those counts reproduces the header's boundaries
 * exactly, which is the check below.
 *
 * Grades 1–3 already had lists scraped from teaching sites; this script only
 * writes grades 4–6 so the shipped lists are not disturbed.
 *
 * Usage:
 *   node tool/build-books.cjs
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(__dirname, 'data', 'renjiao-writing-list.txt');
const OUT = path.join(__dirname, 'data', 'books');

/** id, title, count, first character, last character — all from the file header. */
const VOLUMES = [
  ['g1a', '一年级上册', 100, '一', '厂'],
  ['g1b', '一年级下册', 200, '春', '房'],
  ['g2a', '二年级上册', 250, '找', '路'],
  ['g2b', '二年级下册', 250, '诗', '通'],
  ['g3a', '三年级上册', 250, '晨', '险'],
  ['g3b', '三年级下册', 250, '融', '偏'],
  ['g4a', '四年级上册', 250, '潮', '溉'],
  ['g4b', '四年级下册', 250, '杂', '拆'],
  ['g5a', '五年级上册', 220, '宜', '某'],
  ['g5b', '五年级下册', 180, '昼', '憎'],
  ['g6a', '六年级上册', 180, '毯', '陡'],
  ['g6b', '六年级下册', 120, '醋', '怖'],
];

const NEW_VOLUMES = new Set(['g4a', 'g4b', 'g5a', 'g5b', 'g6a', 'g6b']);

const lines = fs.readFileSync(SRC, 'utf8').split('\n')
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#'));

let cursor = 0;
const slices = {};
for (const [id, title, count, first, last] of VOLUMES) {
  const chars = lines.slice(cursor, cursor + count);
  cursor += count;
  if (chars.length !== count) {
    console.error(`${title} 取到 ${chars.length} 字，应为 ${count}`);
    process.exit(2);
  }
  // The header states each volume's first and last character; use it to prove
  // the split lands on the right boundaries.
  if (chars[0] !== first || chars[chars.length - 1] !== last) {
    console.error(`${title} 边界不符：取到 ${chars[0]}…${chars[chars.length - 1]}，应为 ${first}…${last}`);
    process.exit(2);
  }
  slices[id] = chars;
}
console.log('分册边界全部核对通过，共 %d 字', cursor);

fs.mkdirSync(OUT, { recursive: true });
for (const [id, title, count] of VOLUMES) {
  if (!NEW_VOLUMES.has(id)) continue;
  const file = path.join(OUT, id + '.json');
  const payload = {
    book: title,
    sourceNotes:
      '统编版（部编版）小学语文《写字表》（会写的字）。来源：'
      + 'zispace/hanzi-chars-ext「中国大陆人民教育出版社《义务教育教科书·语文》（统编版）写字表」，'
      + `按教材顺序与分册字数切分，边界已与该文件头标注的首末字核对通过。共 ${count} 字。`
      + '注：该表只到册不到课，本册暂无课次分组。',
    lessons: [],
    all: slices[id],
  };
  fs.writeFileSync(file, JSON.stringify(payload, null, 1) + '\n');
  console.log('写入 %s  %s  %d 字', id + '.json', title, slices[id].length);
}
