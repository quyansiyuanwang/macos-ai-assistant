#!/bin/bash
# 构建 AiSiri.app（无需 Xcode，使用 SwiftPM + 命令行工具链）
set -e
cd "$(dirname "$0")"

echo "==> 编译 Release"
swift build -c release

BIN=".build/release/AiSiri"
APP="$HOME/Applications/AiSiri.app"

echo "==> 打包 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AiSiri"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# pi Agent 运行时（基于 pi-agent-core + pi-ai）
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo "==> 安装 agent 依赖"
  (cd agent && npm install --no-audit --no-fund --silent) || echo "⚠️  npm install 失败"
  if [ -f agent/node_modules/@earendil-works/pi-agent-core/package.json ]; then
    rm -rf "$APP/Contents/Resources/agent"
    cp -R agent "$APP/Contents/Resources/agent"
    rm -rf "$APP/Contents/Resources/agent/node_modules/.bin"
    echo "    pi Agent 运行时已打包"
  else
    echo "⚠️  agent 依赖不完整，pi 运行时会回退到内置实现"
  fi
else
  echo "⚠️  未检测到 Node.js，pi Agent 运行时会回退到内置实现"
fi

echo "==> 临时签名"
codesign --force --sign - --entitlements Resources/AiSiri.entitlements "$APP" 2>/dev/null || \
codesign --force --sign - "$APP"

echo "==> 初始化配置 ~/.config/aisiri/config.json"
mkdir -p "$HOME/.config/aisiri"
if [ ! -f "$HOME/.config/aisiri/config.json" ]; then
  cp config.example.json "$HOME/.config/aisiri/config.json"
  echo "⚠️  请打开 App「设置 → 模型」填入 API Key（或先 export DEEPSEEK_API_KEY 再运行本脚本）"
fi
chmod 600 "$HOME/.config/aisiri/config.json" 2>/dev/null || true

mkdir -p "$HOME/.local/bin"
ln -sf "$APP/Contents/MacOS/AiSiri" "$HOME/.local/bin/aisiri"

echo ""
echo "✅ 完成"
echo "  App:    $APP"
echo "  CLI:    $HOME/.local/bin/aisiri"
echo "  配置:   $HOME/.config/aisiri/config.json"
