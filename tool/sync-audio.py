#!/usr/bin/env python3
"""Rebuilds only the syllable clips whose reading carrier changed.

tool/verify-audio.py checks clips against the carrier table; this script is the
counterpart that brings the clips back in line after tool/content/syllable_samples.tsv
is edited. Re-synthesising all 1123 syllables takes ~20 minutes, so this narrows
the work to the syllables whose carrier actually differs from the last build.

Usage:
  python3 tool/sync-audio.py [--all]
"""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
VOICE = "Tingting"


def md5(path):
    return hashlib.md5(pathlib.Path(path).read_bytes()).hexdigest()


def synthesise(char, target):
    aiff = target.with_suffix(".aiff")
    subprocess.run(["/usr/bin/say", "-v", VOICE, "-o", str(aiff), char],
                   check=True, capture_output=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(aiff),
                    "-c:a", "aac", "-b:a", "16k", "-ac", "1", "-ar", "16000",
                    str(target)], check=True, capture_output=True)
    aiff.unlink(missing_ok=True)


def main():
    carrier = {}
    for line in (ROOT / "tool/content/syllable_samples.tsv").read_text().splitlines():
        if line and not line.startswith("#"):
            parts = line.split("\t")
            if len(parts) >= 2:
                carrier[parts[0].removesuffix(".m4a")] = parts[1]

    catalog = json.loads((ROOT / "assets/data/catalog.json").read_text())
    by_syllable = {}
    for entry in catalog:
        syllable = str(entry.get("syllable", "")).removesuffix(".m4a")
        if syllable:
            by_syllable.setdefault(syllable, []).append(entry["char"])

    syllables = [l.split("\t")[0].removesuffix(".m4a")
                 for l in (ROOT / "tool/build/syllables.txt").read_text().strip().split("\n")]

    chars_dir = ROOT / "assets/audio/chars"
    syl_dir = ROOT / "assets/audio/syllables"
    chars_dir.mkdir(parents=True, exist_ok=True)

    if "--all" in sys.argv:
        todo = [s for s in syllables if s in carrier]
    else:
        todo = []
        for s in syllables:
            if s not in carrier or s not in by_syllable:
                continue
            probe = chars_dir / f"{ord(by_syllable[s][0]):x}.m4a"
            with tempfile.TemporaryDirectory() as tmp:
                want = pathlib.Path(tmp) / "probe.m4a"
                synthesise(carrier[s], want)
                if not probe.exists() or md5(probe) != md5(want):
                    todo.append(s)

    print(f"待更新音节 {len(todo)} / {len(syllables)}")

    tmpdir = pathlib.Path(tempfile.mkdtemp())
    changed = 0
    for i, s in enumerate(todo, 1):
        clip = tmpdir / f"{i}.m4a"
        try:
            synthesise(carrier[s], clip)
        except subprocess.CalledProcessError as error:
            print(f"失败 {s} 「{carrier[s]}」 {error}")
            continue
        shutil.copyfile(clip, syl_dir / f"{s}.m4a")
        # 有些音节只出现在组词里（如 bo4 「簸箕」的簸），字库里没有对应单字，
        # 那就只写音节音频，没有字音频需要回填。
        for ch in by_syllable.get(s, []):
            shutil.copyfile(clip, chars_dir / f"{ord(ch):x}.m4a")
        changed += 1
        if i % 50 == 0:
            print(f"  ... {i}/{len(todo)}")

    shutil.rmtree(tmpdir, ignore_errors=True)
    print(f"已更新 {changed} 个音节的音频（字音频同步回填）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
