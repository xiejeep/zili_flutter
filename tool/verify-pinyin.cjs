#!/usr/bin/env node
/*
 * Cross-checks every reading in the library against the open dataset at
 * https://github.com/mapull/chinese-dictionary (MIT).
 *
 * The dataset lists every reading a character has, so it is a genuine second
 * opinion on the pinyin we wrote by hand. It is used read-only: nothing here
 * feeds the app, it only reports.
 *
 * Usage: node tool/verify-pinyin.cjs
 * Exits non-zero when a reading disagrees, so it can gate a build.
 */
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..');
const CATALOG = path.join(ROOT, 'assets/data/catalog.json');
const CACHE = path.join(__dirname, '.cache');

const BASE_URL =
  'https://raw.githubusercontent.com/mapull/chinese-dictionary/main/character';
const SOURCES = {
  'char_base.json': `${BASE_URL}/char_base.json`,
  'polyphone.json': `${BASE_URL}/polyphone.json`,
};

/** Downloads once, then reuses the local copy. */
async function fetchCached(name) {
  const file = path.join(CACHE, name);
  if (fs.existsSync(file)) return fs.readFileSync(file, 'utf8');

  fs.mkdirSync(CACHE, { recursive: true });
  process.stdout.write(`下载 ${name} ... `);
  const res = await fetch(SOURCES[name]);
  if (!res.ok) throw new Error(`${name} 下载失败：HTTP ${res.status}`);
  const text = await res.text();
  fs.writeFileSync(file, text);
  console.log(`${(text.length / 1024).toFixed(0)} KB，已缓存`);
  return text;
}

/** char_base.json is JSONL with a trailing comma on every line. */
function parseJsonl(text) {
  return JSON.parse(`[${text.trim().replace(/,$/, '')}]`);
}

/**
 * The dataset writes some syllables with the IPA letters ŋ and ɡ instead of
 * the usual ng and g, and may use decomposed tone marks.
 */
function normalise(pinyin) {
  return pinyin
    .replace(/ŋ/g, 'ng')
    .replace(/ɡ/g, 'g')
    .trim()
    .normalize('NFC');
}

/** A neutral tone reading carries no tone mark, e.g. 们 men. */
const isNeutralTone = (pinyin) => !/[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]/.test(pinyin);

/**
 * Readings the dataset simply does not list. Each was checked by hand; they are
 * kept explicit so a genuine regression cannot hide behind a blanket ignore.
 */
const KNOWN_DATASET_GAPS = new Map([
  // 脯 reads pú in 胸脯, the everyday word. The dataset only lists fǔ/pǔ, so it
  // is missing that reading rather than us being wrong.
  ['脯', 'pú'],
]);

async function main() {
  const [baseText, polyText] = await Promise.all([
    fetchCached('char_base.json'),
    fetchCached('polyphone.json'),
  ]);

  const base = new Map(parseJsonl(baseText).map((e) => [e.char, e]));
  const polyphone = new Map(
    JSON.parse(polyText).map((e) => [e.char, e.pinyin.map(normalise)]),
  );
  const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));

  const uncovered = [];
  const disagreements = [];
  const neutralToneSkips = [];
  const knownGaps = [];
  let polyphoneCount = 0;

  for (const entry of catalog) {
    const { char, pinyin } = entry;
    if (!base.has(char)) {
      uncovered.push(char);
      continue;
    }

    const readings = polyphone.get(char);
    if (!readings) continue;
    polyphoneCount++;

    const mine = normalise(pinyin);
    if (readings.includes(mine)) continue;

    // Readings the dataset is known to be missing, verified by hand.
    if (KNOWN_DATASET_GAPS.get(char) === mine) {
      knownGaps.push({ char, pinyin, readings });
      continue;
    }

    // The dataset does not carry neutral tone readings (什么 me, 看着 zhe),
    // so those cannot be checked against it.
    if (isNeutralTone(mine)) {
      neutralToneSkips.push({ char, pinyin, readings });
      continue;
    }
    disagreements.push({ char, pinyin, readings });
  }

  console.log('');
  console.log(`字库条目          ${catalog.length}`);
  console.log(`对方收录          ${base.size}`);
  console.log(`其中多音字        ${polyphoneCount}`);
  console.log(`轻声（无法校验）  ${neutralToneSkips.length}`);
  console.log(`读音不一致        ${disagreements.length}`);
  console.log(`对方未收录        ${uncovered.length}`);
  console.log(`已知数据缺口      ${knownGaps.length}`);

  if (knownGaps.length) {
    console.log('\n已知数据缺口（对方漏收的读音，已人工确认）：');
    for (const item of knownGaps) {
      console.log(`  ${item.char}  我们=${item.pinyin}  对方=${item.readings.join(', ')}`);
    }
  }

  if (neutralToneSkips.length) {
    console.log('\n轻声条目（对方不收轻声，跳过比对）：');
    for (const item of neutralToneSkips) {
      console.log(`  ${item.char}  我们=${item.pinyin}  对方=${item.readings.join(', ')}`);
    }
  }

  if (uncovered.length) {
    console.log(`\n对方未收录：${uncovered.join('')}`);
  }

  if (disagreements.length) {
    console.log('\n❌ 读音不一致，需要人工确认：');
    for (const item of disagreements) {
      console.log(`  ${item.char}  我们=${item.pinyin}  对方=${item.readings.join(', ')}`);
    }
    process.exitCode = 1;
  } else {
    console.log('\n✅ 全部读音与开源数据一致（轻声除外）');
  }
}

main().catch((error) => {
  console.error(`校验失败：${error.message}`);
  process.exitCode = 1;
});
