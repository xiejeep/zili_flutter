/**
 * Generates one audio clip per character in the library.
 *
 * The clip's *content* comes from the reading carrier of the character's
 * syllable (see tool/content/syllable_samples.tsv) rather than from the
 * character itself. That indirection matters: a dozen characters in the
 * library are polyphones whose textbook reading is not what macOS `say`
 * picks by default (发 fà, 爪 zhuǎ, 拓 tà, 都 dū ...), so reading the
 * character directly would mispronounce them.
 *
 * Because a clip only depends on the syllable, characters that share a
 * syllable share the clip: the script synthesises once per syllable and
 * copies the result, so 3510 characters cost about 1123 `say` calls.
 *
 * Output: assets/audio/chars/<codepoint>.m4a  (lowercase hex, e.g. 4f60.m4a)
 *         assets/data/char_audio.json         (character -> file name)
 *
 * Usage:
 *   node tool/build-char-audio.cjs [--force]
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const CATALOG = path.join(ROOT, 'assets', 'data', 'catalog.json');
const SAMPLES = path.join(__dirname, 'content', 'syllable_samples.tsv');
const OUT_DIR = path.join(ROOT, 'assets', 'audio', 'chars');
const MAP_FILE = path.join(ROOT, 'assets', 'data', 'char_audio.json');
const FORCE = process.argv.includes('--force');
const CONCURRENCY = 4;

/* ---------- input ---------- */

const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
if (!fs.existsSync(SAMPLES)) {
  console.error('缺少读音载体表：%s（先运行样本字挑选脚本）', SAMPLES);
  process.exit(2);
}

// syllable -> carrier character
const carrier = new Map();
for (const line of fs.readFileSync(SAMPLES, 'utf8').split('\n')) {
  if (!line || line.startsWith('#')) continue;
  const [name, char] = line.split('\t');
  if (name && char) carrier.set(name.replace(/\.m4a$/, ''), char);
}

// syllable -> [characters]
const bySyllable = new Map();
let missing = 0;
for (const entry of catalog) {
  const syllable = String(entry.syllable || '').replace(/\.m4a$/, '');
  if (!syllable) { missing++; continue; }
  if (!bySyllable.has(syllable)) bySyllable.set(syllable, []);
  bySyllable.get(syllable).push(entry.char);
}
console.log('字库 %d 字，音节 %d 个，无音节字段 %d 字',
  catalog.length, bySyllable.size, missing);

const noCarrier = [...bySyllable.keys()].filter((s) => !carrier.has(s));
if (noCarrier.length) {
  console.error('以下音节缺少读音载体：%s', noCarrier.join(' '));
  process.exit(2);
}

/* ---------- work list ---------- */

fs.mkdirSync(OUT_DIR, { recursive: true });
const fileName = (char) => char.codePointAt(0).toString(16) + '.m4a';

const todo = [...bySyllable.entries()].filter(([syllable, chars]) =>
  FORCE || chars.some((c) => !fs.existsSync(path.join(OUT_DIR, fileName(c)))));
console.log('待处理音节 %d / %d', todo.length, bySyllable.size);

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'zili-chars-'));
let done = 0;
let failed = 0;

/** Synthesises the carrier once, then copies it to every character's file. */
function make([syllable, chars], slot) {
  const aiff = path.join(tmpDir, `${slot}.aiff`);
  const clip = path.join(tmpDir, `${slot}.m4a`);
  try {
    execFileSync('say', ['-v', 'Tingting', '-o', aiff, carrier.get(syllable)], { stdio: 'ignore' });
    execFileSync('ffmpeg', [
      '-y', '-loglevel', 'error', '-i', aiff,
      '-c:a', 'aac', '-b:a', '16k', '-ac', '1', '-ar', '16000', clip,
    ], { stdio: 'ignore' });
    fs.rmSync(aiff, { force: true });
    for (const c of chars) fs.copyFileSync(clip, path.join(OUT_DIR, fileName(c)));
    fs.rmSync(clip, { force: true });
    return true;
  } catch (error) {
    console.error('失败 %s %s %s', syllable, carrier.get(syllable), error.message);
    return false;
  }
}

async function run() {
  let next = 0;
  const workers = Array.from({ length: CONCURRENCY }, async (_, slot) => {
    while (next < todo.length) {
      const item = todo[next++];
      if (make(item, slot)) done++; else failed++;
    }
  });
  await Promise.all(workers);
}

run().then(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });

  // character -> file name, for the app to read without re-deriving codepoints
  const map = {};
  for (const [syllable, chars] of bySyllable) {
    for (const c of chars) map[c] = fileName(c);
  }
  fs.writeFileSync(MAP_FILE, JSON.stringify(map) + '\n');

  const files = fs.readdirSync(OUT_DIR).filter((f) => f.endsWith('.m4a'));
  const bytes = files.reduce((n, f) => n + fs.statSync(path.join(OUT_DIR, f)).size, 0);
  console.log('已生成音节 %d，失败 %d', done, failed);
  console.log('字音频文件 %d 个，总体积 %s MB', files.length, (bytes / 1048576).toFixed(2));
  console.log('映射已写入 %s（%d 条）', MAP_FILE, Object.keys(map).length);
});
