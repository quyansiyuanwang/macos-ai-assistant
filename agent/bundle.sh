#!/bin/bash
# 重新生成 agent/server.bundle.mjs（自包含单文件，无需 node_modules）
set -e
cd "$(dirname "$0")"
npm install --no-audit --no-fund --silent
npx esbuild server.mjs --bundle --platform=node --format=esm --target=node18 \
  --outfile=server.bundle.mjs --log-level=warning
echo "✅ server.bundle.mjs  ($(du -h server.bundle.mjs | cut -f1))"
