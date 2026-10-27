/**
 * Synthesises one audio clip per pinyin syllable with the macOS Tingting voice.
 *
 * The app concatenates these clips to pronounce characters, words and phrases,
 * so the library needs one file per distinct syllable rather than one per entry
 * — that is what keeps 3500 characters down to roughly 1400 audio files.
 *
 * The list of syllables comes from tool/build/syllables.txt, which
 * tool/build-library.cjs writes.
 *
 * Usage:
 *   node tool/build-audio.cjs [--force]
 *
 * Output: assets/audio/syllables/<syllable>.m4a
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'assets', 'audio', 'syllables');
const LIST = path.join(__dirname, 'build', 'syllables.txt');
const FORCE = process.argv.includes('--force');
const CONCURRENCY = 4;

if (!fs.existsSync(LIST)) {
  console.error('缺少音节清单，请先运行：node tool/build-library.cjs');
  process.exit(2);
}
fs.mkdirSync(OUT_DIR, { recursive: true });

const rows = fs.readFileSync(LIST, 'utf8').trim().split('\n')
  .map((row) => row.split('\t'))
  .filter(([name, text]) => name && text);

const todo = rows.filter(([name]) => FORCE || !fs.existsSync(path.join(OUT_DIR, name)));
console.log('音节总数 %d，待生成 %d', rows.length, todo.length);

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'zili-audio-'));
let done = 0;
let failed = 0;

/** Synthesises one syllable. Runs in a worker below. */
function make([name, text], slot) {
  const aiff = path.join(tmpDir, `${slot}.aiff`);
  const target = path.join(OUT_DIR, name);
  try {
    execFileSync('say', ['-v', 'Tingting', '-o', aiff, text], { stdio: 'ignore' });
    execFileSync('ffmpeg', [
      '-y', '-loglevel', 'error', '-i', aiff,
      '-c:a', 'aac', '-b:a', '16k', '-ac', '1', '-ar', '16000', target,
    ], { stdio: 'ignore' });
    fs.rmSync(aiff, { force: true });
    return true;
  } catch (error) {
    console.error('失败 %s %s %s', name, text, error.message);
    return false;
  }
}

// A tiny worker pool: `say` is the slow part and it is process based, so a few
// in flight at once cuts the wall clock substantially.
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
  const files = fs.readdirSync(OUT_DIR).filter((f) => f.endsWith('.m4a'));
  const bytes = files.reduce((n, f) => n + fs.statSync(path.join(OUT_DIR, f)).size, 0);
  console.log('已生成 %d，失败 %d', done, failed);
  console.log('音频文件总数 %d，总体积 %s MB', files.length, (bytes / 1048576).toFixed(2));
});
