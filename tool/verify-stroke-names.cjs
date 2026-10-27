/**
 * Validates the automatic stroke-name resolver against the 1295 characters whose
 * names were resolved by hand, and then checks that every name folds down to the
 * official GF 0023-2020 category for all 3500 level-1 characters.
 *
 * The hand-resolved set is the ground truth: it was cross-checked against an
 * independent stroke-name dataset when it was produced.
 *
 * Usage:
 *   node tool/verify-stroke-names.cjs
 *
 * Exits non-zero on any disagreement, so it can gate a build.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const ROOT = path.resolve(__dirname, '..');
const NODE_MODULES = '/Users/jmspay/.workbuddy/binaries/node/workspace/node_modules';
const HANZI_DATA = path.join(NODE_MODULES, 'hanzi-writer-data');
const GOLD = '/Users/jmspay/Desktop/my/zili-miniprogram/scripts/source/stroke-names.json';
const { resolveNames } = require('./lib/stroke-names.cjs');

/* ---------- cnchar ---------- */
const ctx = { console, setTimeout, clearTimeout };
ctx.window = ctx; ctx.self = ctx; ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(NODE_MODULES, 'cnchar/cnchar.min.js'), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(path.join(NODE_MODULES, 'cnchar-order/cnchar.order.min.js'), 'utf8'), ctx);
const cnchar = ctx.cnchar;
cnchar.use(ctx.CncharOrder);
const orders = cnchar.order.dict.orders;

/* ---------- decomposition (for 横斜钩) ---------- */
const decompositions = {};
const mmah = path.join(__dirname, '.cache', 'dictionary.txt');
if (fs.existsSync(mmah)) {
  for (const line of fs.readFileSync(mmah, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    const o = JSON.parse(line);
    decompositions[o.character] = o.decomposition;
  }
}

const readMedians = (char) => {
  const file = path.join(HANZI_DATA, char + '.json');
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf8')).medians;
};

/* ---------- 1. compare against the hand-resolved ground truth ---------- */
const gold = JSON.parse(fs.readFileSync(GOLD, 'utf8'));
let agree = 0;
const diffs = [];
const diffKinds = {};

for (const [char, expected] of Object.entries(gold)) {
  const letters = orders[char];
  const medians = readMedians(char);
  if (!letters || !medians) { diffs.push(`${char} 缺少数据`); continue; }
  const got = resolveNames(char, letters, medians, decompositions[char]);
  if (got.join('') === expected.join('')) { agree++; continue; }
  const pairs = [];
  for (let i = 0; i < Math.max(got.length, expected.length); i++) {
    if (got[i] !== expected[i]) pairs.push(`${got[i] || '-'}→${expected[i] || '-'}`);
  }
  diffs.push(`${char} [${pairs.join(', ')}]`);
  for (const p of pairs) diffKinds[p] = (diffKinds[p] || 0) + 1;
}

const total = Object.keys(gold).length;
console.log('=== 与人工判定对比（%d 字）===', total);
console.log('一致      %d / %d  (%s%%)', agree, total, (agree / total * 100).toFixed(1));
console.log('不一致    %d', diffs.length);
if (diffs.length) {
  console.log('差异类型:');
  for (const [k, v] of Object.entries(diffKinds).sort((a, b) => b[1] - a[1])) {
    console.log('  %s  ×%d', k, v);
  }
  console.log('样例: %s', diffs.slice(0, 12).join(' | '));
}

/* ---------- 2. every name must fold to the official category ---------- */
const FOLD = { 横: '1', 提: '1', 竖: '2', 竖钩: '2', 撇: '3', 点: '4', 捺: '4' };
const fold = (n) => FOLD[n] || '5';

const level1 = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'level1.json'), 'utf8'));
let checked = 0;
const foldErrors = [];
const noData = [];

for (const char of Object.keys(level1)) {
  const letters = orders[char];
  const medians = readMedians(char);
  if (!letters || !medians) { noData.push(char); continue; }
  const names = resolveNames(char, letters, medians, decompositions[char]);
  if (names.some((n) => !n)) { foldErrors.push(char + ' 有空名'); continue; }
  const mine = names.map(fold).join('');
  if (mine !== level1[char].codes) {
    foldErrors.push(`${char} 我们=${mine} 官方=${level1[char].codes}`);
  }
  checked++;
}

console.log('\n=== 与官方笔顺类别对照（3500 字）===');
console.log('可对照    %d / %d', checked, Object.keys(level1).length);
console.log('缺数据    %d %s', noData.length, noData.slice(0, 20).join(''));
console.log('类别不符  %d', foldErrors.length);
if (foldErrors.length) console.log('  %s', foldErrors.slice(0, 12).join('\n  '));

const ok = diffs.length === 0 && foldErrors.length === 0 && noData.length === 0;
console.log('\n%s', ok ? '✅ 全部通过' : '❌ 存在差异');
process.exit(ok ? 0 : 1);
