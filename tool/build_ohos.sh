#!/usr/bin/env bash
# HarmonyOS builds need three environment fixes on this machine, see
# docs/flutter-migration-plan.md for the full explanation.
set -euo pipefail

export PATH="$HOME/fvm/versions/oh-3.41.9-release/bin:/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH"

# 1. hvigor cannot locate the SDK without this.
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"

# 2. hvigor requires Node 18, the system PATH ships Node 22.
export NODE_HOME="/Applications/DevEco-Studio.app/Contents/tools/node"

# 3. Injected node options intercept ohpm's symlinks; local proxies break the
#    flutter_tester websocket. Neither applies inside DevEco Studio.
unset NODE_OPTIONS HTTP_PROXY HTTPS_PROXY http_proxy https_proxy || true
export NO_PROXY="localhost,127.0.0.1"

cd "$(dirname "$0")/.."
flutter "${@:-build hap --debug}"
