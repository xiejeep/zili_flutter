#!/usr/bin/env python3
"""Checks that every character clip on disk still matches its reading carrier.

The clips under assets/audio/chars were produced by tool/build-char-audio.cjs
from the carriers in tool/content/syllable_samples.tsv. This script re-synthesises
each carrier and compares the result with the file that was shipped, so a stale
or hand-edited clip cannot survive unnoticed -- which is exactly the failure
that hid in the old syllable pipeline (see docs/PROGRESS.md, P21).

Requires pypinyin only if --audit is used; a plain run needs just say/ffmpeg.

Usage:
  python3 tool/verify-audio.py            # verify clips against the carrier table
  python3 tool/verify-audio.py --audit    # additionally flag carriers that are
                                          # polyphones whose default reading may
                                          # differ from the target syllable
Exit code 0 when everything matches, 1 otherwise.
"""
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "assets" / "data" / "catalog.json"
SAMPLES = ROOT / "tool" / "content" / "syllable_samples.tsv"
CLIPS = ROOT / "assets" / "audio" / "chars"
VOICE = "Tingting"
JOBS = 4


def md5(path):
    return hashlib.md5(pathlib.Path(path).read_bytes()).hexdigest()


def synthesise(char, target, voice=VOICE):
    aiff = target.with_suffix(".aiff")
    subprocess.run(["/usr/bin/say", "-v", voice, "-o", str(aiff), char],
                   check=True, capture_output=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(aiff),
                    "-c:a", "aac", "-b:a", "16k", "-ac", "1", "-ar", "16000",
                    str(target)], check=True, capture_output=True)
    aiff.unlink(missing_ok=True)


def clip_name(char):
    return f"{ord(char):x}.m4a"


def main():
    audit = "--audit" in sys.argv

    carrier = {}
    for line in SAMPLES.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            carrier[parts[0].removesuffix(".m4a")] = parts[1]

    chars = {}
    for entry in json.loads(CATALOG.read_text()):
        syllable = str(entry.get("syllable", "")).removesuffix(".m4a")
        if syllable:
            chars.setdefault(syllable, []).append(entry["char"])

    if not CLIPS.is_dir():
        print(f"找不到 {CLIPS}，先运行 node tool/build-char-audio.cjs")
        return 1

    missing = [c for c in carrier if c not in chars]
    if missing:
        print(f"载体表里有 {len(missing)} 个音节不在字库中：{' '.join(sorted(missing)[:10])}")

    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)

        def check(syllable):
            char = carrier[syllable]
            ref = tmp / f"{syllable}.m4a"
            try:
                synthesise(char, ref)
            except subprocess.CalledProcessError as error:
                return syllable, char, "合成失败", error
            want = md5(ref)
            bad = []
            for ch in chars.get(syllable, []):
                clip = CLIPS / clip_name(ch)
                if not clip.exists():
                    bad.append(f"{ch}(缺文件)")
                elif md5(clip) != want:
                    bad.append(f"{ch}(内容不符)")
            return syllable, char, bad, None

        stale, errors = [], []
        with ThreadPoolExecutor(JOBS) as pool:
            for syllable, char, bad, error in pool.map(check, sorted(carrier)):
                if error or bad == "合成失败":
                    errors.append((syllable, char))
                elif bad:
                    stale.append((syllable, char, bad))

    total = sum(len(v) for v in chars.values())
    print(f"字音频 {total} 个，音节 {len(chars)} 个，载体 {len(carrier)} 个")
    if errors:
        print(f"\n合成失败 {len(errors)} 个：")
        for syllable, char in errors:
            print(f"  {syllable:<9} 载体「{char}」")
    if stale:
        print(f"\n与载体不一致 {len(stale)} 个音节 —— 产物过期或被人改过：")
        for syllable, char, bad in stale:
            print(f"  {syllable:<9} 载体「{char}」  受影响：{' '.join(bad[:8])}")
    if not errors and not stale:
        print("\n全部一致：磁盘上的音频与载体表完全吻合。")

    if audit:
        try:
            from pypinyin import Style, pinyin
        except ImportError:
            print("\n（--audit 需要 pypinyin，已跳过）")
        else:
            risky = []
            for syllable, char in sorted(carrier.items()):
                readings = set(pinyin(char, style=Style.TONE3, heteronym=True)[0] or [])
                if len(readings) > 1:
                    default = (pinyin(char, style=Style.TONE3)[0] or [""])[0]
                    if default != syllable:
                        risky.append((syllable, char, default, sorted(readings)))
            print(f"\n--- 载体自查（--audit）---")
            print(f"载体是多音字、且字典默认读音不是目标音节的：{len(risky)} 个")
            print("这些依赖 TTS 自身读音而非字典唯一性，建议试听确认：")
            for syllable, char, default, readings in risky:
                print(f"  {syllable:<9}「{char}」 目标 {syllable} / 字典默认 {default} / 读音集 {' '.join(readings)}")

    return 1 if (errors or stale) else 0


if __name__ == "__main__":
    sys.exit(main())
