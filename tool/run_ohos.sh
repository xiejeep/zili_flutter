#!/usr/bin/env bash
# Builds, installs and launches the HarmonyOS debug app on a device.
#
# Requires a debug signature in ohos/build-profile.json5, see
# docs/OHOS_SIGNING.md. Usage: ./tool/run_ohos.sh [device_id]
set -euo pipefail

DEVICE_ID="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HDC="${HDC:-$HOME/Library/OpenHarmony/Sdk/23/toolchains/hdc}"
FLUTTER="${FLUTTER:-$HOME/fvm/versions/oh-3.41.9-release/bin/flutter}"
OHPM_BIN="/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin"
HVIGOR_BIN="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin"

export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export NODE_HOME="/Applications/DevEco-Studio.app/Contents/tools/node"
# These only affect the sandboxed agent shell, a normal terminal needs neither.
unset NODE_OPTIONS HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
export NO_PROXY="localhost,127.0.0.1"

cd "$SCRIPT_DIR"
PATH="$OHPM_BIN:$HVIGOR_BIN:$PATH" "$FLUTTER" build hap --debug --target-platform ohos-arm64

HAP="build/ohos/hap/entry-default-signed.hap"
if [ ! -f "$HAP" ]; then
  echo "未找到已签名的 HAP，请先在 DevEco Studio 里配置签名（见 docs/OHOS_SIGNING.md）" >&2
  exit 1
fi

if [ -n "$DEVICE_ID" ]; then
  "$HDC" -t "$DEVICE_ID" install -r "$HAP"
  "$HDC" -t "$DEVICE_ID" shell aa start -b com.zili.ziliFlutter -a EntryAbility
else
  "$HDC" install -r "$HAP"
  "$HDC" shell aa start -b com.zili.ziliFlutter -a EntryAbility
fi

echo "字里已启动。"
