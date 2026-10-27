# 字里 · Flutter 三端

汉字启蒙学习应用，一套代码覆盖 iOS / Android / HarmonyOS。

## 当前进度

三端编译均已通过：Android APK、iOS Runner.app、HarmonyOS HAP。
字库覆盖 **3510 字**（《通用规范汉字表》一级字 3500 + 小学写字表补充的 10 个二级字），
教材册次覆盖**小学 1–6 年级全部 12 册写字表（2500 字）**；资产（3510 字 + 1123 音节音频）
已入 `assets/`；查字搜索、笔顺动画、读音播放、生字本、字帖导出（图片存相册 / A4 PDF）、
逐笔缩略图已实现。详细进度见 **[docs/PROGRESS.md](docs/PROGRESS.md)**。

> 鸿蒙 HAP 目前是未签名的，装真机前需先配签名，见 [docs/OHOS_SIGNING.md](docs/OHOS_SIGNING.md)。

## 环境要求

- Flutter 鸿蒙分支 `3.41.10-ohos`（本机经 fvm 管理，`oh-3.41.9-release`）
- DevEco Studio + HarmonyOS SDK（鸿蒙构建）
- Xcode（iOS）、Android SDK（Android）

## 构建

```sh
flutter run                    # 连接设备后直接运行
flutter build apk --debug      # Android
flutter build ios --no-codesign # iOS
./tool/build_ohos.sh           # HarmonyOS（脚本已固化所需环境变量）
./tool/run_ohos.sh             # 鸿蒙：构建 + 安装 + 启动（需先配签名）
```

鸿蒙包需要签名后才能装真机：用 DevEco Studio 打开 `ohos/` 目录，
`File → Project Structure → Signing Configs` 勾选 Automatically generate signature。

## 结构

```
lib/
  data/       字库加载、笔画压缩解码、收藏存储、查字解析
  models/     汉字元信息、教材册次
  painters/   笔顺动画、逐笔缩略图
  services/   音节播放、字帖排版与导出
  pages/      首页、生字本、教材字库
  providers/  Riverpod 状态
  theme/      宣纸米白 + 墨黑 + 朱砂红
  widgets/    查字搜索、通用对话框
assets/
  data/       字库 JSON（catalog / strokes / curriculum）
  audio/      808 个音节音频
  fonts/      字帖用的双字体子集
tool/
  data/level1.json            一级字 3500 基准（官方序号）
  data/books/*.json           教材册次
  content/*.tsv               内容源 字|拼音|释义|组词1|组词2|例句
  lib/stroke-codec.cjs        笔画压缩编解码
  lib/stroke-names.cjs        字母 → 30 种详细笔画名
  build-charset.mjs           生成字表（一级字 3500 + 教材补充 10）
  build-meta.mjs              生成 3510 字元信息
  build-books.cjs             由写字表切分 4–6 年级册次
  build-library.cjs           合并元信息 + 内容 → assets/data/*.json
  build-audio.cjs             合成音节音频
  build_font.cjs              重建字帖字体子集
  extract_official_strokes.mjs 解析教育部 GF 0023-2020 官方笔顺规范
  verify-strokes.mjs          笔顺/笔画数对照官方规范校验
  verify-stroke-names.cjs     笔画名判定对照人工结果校验
  verify-pinyin.cjs           拼音对照开源词典数据校验
  build_ohos.sh               鸿蒙构建
  run_ohos.sh                 鸿蒙构建 + 安装 + 启动
```

### 重建字库

```sh
node tool/build-charset.mjs        # 一级字表（需先跑 extract_official_strokes.mjs）
node tool/build-meta.mjs           # 3500 字字形元信息
node tool/build-library.cjs        # 合并内容 → assets/data/
node tool/build-audio.cjs          # 补齐缺失的音节音频
node tool/verify-strokes.mjs       # 笔顺对官方规范
node tool/verify-pinyin.cjs        # 拼音对开源词典
```

## 字帖导出

每页 5 个字，每字 2 行 × 10 个田字格，首格墨色示范、后两格浅色描红格
（纸面练习用，与屏幕无关）。两种输出共用同一份排版指令，见
`lib/services/sheet_layout.dart`：

- **保存到相册**（默认）：每页一张 PNG，约 216 DPI，直接进系统相册
- **导出 PDF**：A4 排版，适合打印

中文字体是按需子集化的：练习的字走笔画矢量绘制不需要字形，只有标签用字需要嵌字体，
所以 PDF 用的字体资源只有 39KB。改动标签文案后需重新跑 `tool/build_font.cjs`。
图片路径用系统字体，不依赖这份子集。

**不提供分享**：`share_plus` 没有鸿蒙实现，改为保存到本地/相册，三端行为一致。

## 查字

首页顶部可以直接输入想查的字，最多 8 个，每个字出一个按钮，点一下切到那个字。
六册教材没收录的字会标灰并提示「未收录」，而不是静默消失。

## 关于描红

屏幕上**不提供手指描红**——在手机平板上用手指描字对练字没有帮助。
字帖里的浅色描红格保留，那是给孩子用笔在纸上练的。

## 字库来源（重要，上架前请先看这里）

各字段的可信度**并不一致**，其中释义、组词、例句是 AI 撰写的，未经权威来源核对：

| 字段 | 来源 | 可信度 |
|---|---|---|
| **笔顺 / 笔画数** | Hanzi Writer Data 2.0.1 派生。**已用教育部官方规范 GF 0023-2020《通用规范汉字笔顺规范》逐字校验，3500 字 0 处不一致** | **高（官方规范级）** |
| **收录范围** | **《通用规范汉字表》一级字 3500**（国务院国发〔2013〕23 号；教育部明示其「可以作为义务教育阶段的识字标准」）+ 小学写字表要求的 10 个二级字，共 **3510 字**。覆盖小学课标要求（认识 3000 / 会写 2500） | **高（国标）** |
| 笔画路径 | Hanzi Writer Data 2.0.1（Arphic Public License） | 高（权威开源数据） |
| 笔画名称 | `cnchar-order` 字母 + 歧义判定规则，**与 1295 字人工判定 100% 一致** | 高 |
| 部首 / 结构 | `cnchar-radical` 数据包（21 字用 Hanzi Writer 字典兜底） | 中—高（**尚未用官方标准校验**） |
| 音节音频 | macOS `say -v Tingting` 合成 | 高（机械合成） |
| 拼音 | **Unicode Unihan kMandarin**（在人工拼音上实测 97.8%，优于其他免费源）。**已用开源词典数据交叉校验，3500 字 0 处不一致** | 高 |
| 教材册次 | **1–3 年级**：抓取公开教学网站，两源交叉核对，来源 URL 记在 `sourceNotes`；**4–6 年级**：来自 `zispace/hanzi-chars-ext` 的统编版写字表，按分册字数切分并核对首末字边界。共 **12 册 2500 字** | 中—高（**未对纸质教材逐字核验**） |
| **释义 / 组词 / 例句** | **AI 撰写**，按统一风格规范生成（释义 10–18 字、口语化、面向 6–9 岁） | **低—中，未经审校** |

> ⚠️ 面向儿童的识字应用里，错误的拼音或释义会把孩子教错。
> 拼音与笔顺均已校验；**释义建议上架前至少把一年级部分交给语文老师审一遍**。
> 开源词典与官方标准数据的评估与取舍见 **[docs/content-review.md](docs/content-review.md)**。

复核（可复现，需联网，结果缓存在 `tool/.cache/`）：

```sh
node tool/verify-pinyin.cjs     # 拼音：对照开源词典数据
node tool/verify-strokes.mjs    # 笔顺/笔画数：对照教育部 GF 0023-2020 官方规范
```

源文件与再生成方式：
- 释义等内容源：`zili-miniprogram/scripts/content/g*.tsv`（可直接改写后重建）
- 重建：`node scripts/build-library.cjs`（小程序工程）→ `tool/export_library.cjs`（本工程）
