/* Builds the two label fonts used by the worksheet PDF.
 *
 * The pdf package ships Latin Type1 fonts only and no CJK at all, so the text
 * that appears on the sheet is subset out of two open fonts and bundled:
 *
 *   zili_label.ttf  Noto Sans SC (SIL OFL)   Chinese labels and CJK punctuation
 *   zili_latin.ttf  DejaVu Sans (Bitstream)  pinyin tone marks, digits, ASCII
 *
 * Two fonts are needed because Noto Sans SC's CJK subset carries no Latin
 * Extended (the pinyin tone marks), while DejaVu carries no full width CJK
 * punctuation.
 *
 * The practice characters themselves are drawn as vector paths from the stroke
 * data, so they need no font glyphs at all.
 *
 * Keep the label strings in sync with lib/services/worksheet_pdf.dart.
 */
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const subsetFont = require('subset-font');

const CJK_TEXT = [
  '字里汉字练习',
  '姓名日期',
  '笔',
  '先描红再独立书写一笔画每天进步点',
  '共页',
  '练习字帖',
  // Space is needed because the label strings embed it between characters.
  ' ',
  '·：，。'
].join('');

const LATIN_TEXT = [
  // Every printable ASCII character, covers page numbers and the name line.
  ...Array.from({ length: 95 }, (_, i) => String.fromCharCode(32 + i)),
  // Pinyin tone marks printed next to each character.
  'āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü'
].join('');

const FONTS = [
  {
    out: 'zili_label.ttf',
    text: CJK_TEXT,
    cache: '/tmp/zili-noto-sans-sc.woff2',
    url: 'https://cdn.jsdelivr.net/npm/@fontsource/noto-sans-sc@5.2.5/files/noto-sans-sc-chinese-simplified-400-normal.woff2',
    label: 'Noto Sans SC'
  },
  {
    out: 'zili_latin.ttf',
    text: LATIN_TEXT,
    cache: '/tmp/zili-dejavu-sans.ttf',
    url: 'https://cdn.jsdelivr.net/npm/dejavu-fonts-ttf@2.37.3/ttf/DejaVuSans.ttf',
    label: 'DejaVu Sans'
  }
];

async function main() {
  const outDir = path.join(__dirname, '../assets/fonts');
  fs.mkdirSync(outDir, { recursive: true });

  for (const font of FONTS) {
    if (!fs.existsSync(font.cache)) {
      console.log('下载', font.label, '…');
      execFileSync('curl', ['-sL', '--max-time', '120', '-o', font.cache, font.url]);
    }
    const output = await subsetFont(fs.readFileSync(font.cache), font.text, {
      targetFormat: 'truetype'
    });
    const file = path.join(outDir, font.out);
    fs.writeFileSync(file, output);
    console.log(
      font.label.padEnd(14),
      [...new Set(font.text)].length + ' 个字形',
      (output.length / 1024).toFixed(1) + 'KB →',
      path.relative(path.join(__dirname, '..'), file)
    );
  }
}

main().catch(error => {
  console.error('字体构建失败:', error.message);
  process.exitCode = 1;
});
