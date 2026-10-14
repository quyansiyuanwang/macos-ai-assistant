# TASK — macos-ai-assistant 接入 Swift 版 pi 子包

> 阶段：**最后执行**。前置条件：`../pi-ai-swift` 与 `../pi-agent-swift` 均已发布可用的 tag。

你是本仓库的开发 agent。目标：把当前基于 Node 子进程的 pi 运行时，替换为直接链接 Swift 包，
实现**运行期零 Node、零额外进程**，同时保留内置后端作为无依赖兜底。

## 背景
当前实现：
- `agent/`：Node 运行时（`server.mjs` + esbuild 产物 `server.bundle.mjs`），依赖 `@earendil-works/pi-*`
- `Sources/AiSiri/PiAgentClient.swift`：通过 stdin/stdout JSONL 驱动该子进程
- `Sources/AiSiri/AIClient.swift`：手写的流式客户端 + 工具循环（内置后端）
- `Sources/AiSiri/Tools.swift`：25 个本机工具，经 `aisiri tool` 执行

## 目标改造
1. `Package.swift`：加入依赖
   ```swift
   .package(path: "../pi-ai-swift"),      // 或 git URL + from: "0.1.0"
   .package(path: "../pi-agent-swift"),
   ```
   目标 `AiSiri` 依赖产品 `PiAI` 与 `PiAgentCore`。
2. **删除** `agent/` 整个目录与 `Sources/AiSiri/PiAgentClient.swift`。
3. 把 `Sources/AiSiri/Tools.swift` 的每个工具改造为 `PiAgentCore.AgentTool` 实现
   （内部执行逻辑不变，仍可走本机 `ToolRunner`）。
4. `AIClient.swift`：
   - 用 `PiAI` 的 `ChatProvider` + `PiAgentCore.Agent` 驱动对话
   - 保留现有手写实现作为 `builtin` 兜底（`agent_runtime=builtin`）
   - `agent_runtime=pi` 走 Swift 包；`auto` 默认走 Swift 包
5. `Config.swift`：`agent_runtime` 语义改为 `auto / package / builtin`（不再有 Node）。
6. `build.sh`：移除 agent 打包与 npm 相关逻辑。
7. `README.md`：更新架构图与「运行期零 Node」说明；删除 pi bundle 相关章节。
8. 冒烟验证：`aisiri ask`、`aisiri agent`（改为走 Swift 包）与 GUI 一轮「流式 + 工具调用」。
9. 提交并推送；`git tag v0.3.0`。

## 验收
- [ ] 仓库内不再有 `agent/`、`PiAgentClient.swift`
- [ ] `swift build && swift test` 通过
- [ ] 运行期无 node 子进程；`ps` 中仅有 `AiSiri.app`
- [ ] 流式输出、工具调用、连续对话、语音链路均正常
- [ ] README 与架构说明同步更新

## 工作方式
小步提交，保持每一步可编译可运行。完成后回报变更摘要与验证命令。
