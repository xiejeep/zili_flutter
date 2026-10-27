/**
 * Resolves cnchar's stroke-order letters into the 30 detailed stroke names the
 * app displays.
 *
 * cnchar's `order.dict.strokeTable` maps each letter to a name, but six letters
 * are genuinely ambiguous — it lists them as e.g. "横撇|横钩" because one letter
 * covers two different stroke forms:
 *
 *   e  横撇 | 横钩           v  横折折 | 横折弯
 *   w  横折折折钩 | 横撇弯钩   x  竖折撇 | 竖折折
 *   y  斜钩 | 卧钩           o  横斜钩 | 横折弯钩（表里只写了横斜钩，不完整）
 *
 * Each is disambiguated below. The rules were derived by studying the 1295
 * characters whose names were resolved by hand and are validated against that
 * set by `tool/verify-stroke-names.cjs` — they reproduce it exactly.
 */
'use strict';

/** cnchar letter -> name, for the letters that are unambiguous. */
const PLAIN = {
  j: '横', f: '竖', s: '撇', k: '点', l: '捺', i: '提',
  c: '横折', r: '横折钩', g: '竖钩', u: '竖弯钩', t: '弯钩',
  h: '竖提', n: '撇折', m: '撇点', p: '横折提', z: '竖折折钩',
  a: '横折折撇', q: '横折折折', d: '点', v: '横折弯', x: '竖折撇',
};

/**
 * Two characters where cnchar's stroke order disagrees with the official
 * standard. Verified against the raw GF 0023-2020 table, which is the
 * authority here. Key is the character, value is the corrected letters.
 */
const ORDER_FIX = {
  德: { 4: 'f' },   // 第 5 笔：cnchar 作撇，官方为竖
  膝: { 13: 's' },  // 第 14 笔：cnchar 作点，官方为撇
};

/** Angle of the stroke's leading direction, in degrees (0 = horizontal). */
function leadingAngle(points) {
  if (!points || points.length < 2) return null;
  const n = Math.max(2, Math.round(points.length * 0.7));
  const a = points[0];
  const b = points[n - 1];
  return Math.atan2(Math.abs(b[1] - a[1]), Math.abs(b[0] - a[0])) * 180 / Math.PI;
}

/**
 * How far the stroke's end swings back from its rightmost point, as a fraction
 * of the stroke's width. 横钩 hooks straight down at the right end, so it stays
 * near 0; 横撇 swings back to the lower left, so it is large.
 */
function backSwing(points) {
  if (!points || points.length < 2) return 1;
  const xs = points.map((p) => p[0]);
  const maxX = Math.max(...xs);
  const minX = Math.min(...xs);
  return (maxX - points[points.length - 1][0]) / Math.max(maxX - minX, 1);
}

/**
 * 横斜钩 (⺄) only occurs in the 风 / 气 families and in 飞 itself; everywhere
 * else the same letter is 横折弯钩 (㇈), as in 九 几 乙.
 */
function hasXieGou(char, decomposition) {
  return /[风气飛飞]/.test(char + (decomposition || ''));
}

/**
 * @param {string} char          the character
 * @param {string} letters       cnchar stroke-order letters, one per stroke
 * @param {number[][][]} medians stroke centre lines, one array of points per stroke
 * @param {string} [decomposition] 部件拆分, e.g. "⿰亻尔"; used for 横斜钩
 * @returns {string[]} one detailed stroke name per stroke
 */
function resolveNames(char, letters, medians, decomposition) {
  const fix = ORDER_FIX[char];
  const seq = fix ? [...letters].map((l, i) => fix[i] || l) : letters;

  const out = [];
  for (let i = 0; i < seq.length; i++) {
    const letter = seq[i];
    const prev = seq[i - 1] || '';
    const next = seq[i + 1] || '';
    const after = seq[i + 2] || '';

    switch (letter) {
      // 横钩 versus 横撇. Two shapes resist the geometry test because their
      // hook swings back like a 撇, so they are matched by letter context:
      //   欠 → 撇-横钩-撇-捺   (吹 次 欣 欧 欲 歌 砍 饮 …)
      //   尔 → 撇-横钩-竖钩-撇 (你 尔)
      // 角 also reads 撇-?-撇 but continues with 折, not 捺, so it stays 横撇.
      case 'e': {
        const qian = prev === 's' && next === 's' && after === 'l';
        const er = prev === 's' && next === 'g' && after === 's';
        const flat = backSwing(medians && medians[i]) < 0.22;
        out.push(qian || er || flat ? '横钩' : '横撇');
        break;
      }
      // 卧钩 (心 必) lies flat then hooks up; 斜钩 (弋 戈) runs diagonally.
      // The two forms overlap in angle, so the preceding stroke decides first:
      // 弋's 斜钩 follows a 横, while 心/必's 卧钩 follows a 点. That separates
      // 袋 (47.5°) from 秘 (47.7°), which no geometric test can tell apart.
      case 'y': {
        const angle = leadingAngle(medians && medians[i]);
        out.push(prev === 'j' ? '斜钩' : (angle !== null && angle < 50 ? '卧钩' : '斜钩'));
        break;
      }
      // 竖弯 only occurs where the next stroke closes the box with a 横
      // (四 西 洒 酒 晒 醒 配); elsewhere it is a sharp 竖折.
      case 'b':
        out.push(next === 'j' ? '竖弯' : '竖折');
        break;
      case 'o':
        out.push(hasXieGou(char, decomposition) ? '横斜钩' : '横折弯钩');
        break;
      // 阝 (横撇弯钩 followed by 竖) versus 乃/场 (横折折折钩 followed by 撇).
      case 'w':
        out.push(next === 'f' ? '横撇弯钩' : '横折折折钩');
        break;
      default:
        out.push(PLAIN[letter] || '');
    }
  }
  return out;
}

module.exports = { resolveNames, leadingAngle, backSwing, PLAIN, ORDER_FIX };
