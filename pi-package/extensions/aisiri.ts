/**
 * AiSiri for pi — 把 macOS 本机操作暴露成 pi 的 Agent 工具。
 *
 * 复用 AiSiri.app 自带 CLI 的 `tool` 子命令（单一实现来源）：
 *   aisiri tool <name> '<json-args>'
 *
 * 通过环境变量配置：
 *   AISIRI_BIN=/path/to/aisiri            自定义 CLI 路径（默认 ~/.local/bin/aisiri）
 *   AISIRI_ENABLE_DANGEROUS=1             额外启用 shell_command / run_applescript
 */

import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { homedir } from "node:os";
import { join } from "node:path";

const exec = promisify(execFile);

function aisiriBin(): string {
  return process.env.AISIRI_BIN || join(homedir(), ".local", "bin", "aisiri");
}

async function runTool(name: string, args: Record<string, unknown>): Promise<string> {
  const bin = aisiriBin();
  try {
    const { stdout, stderr } = await exec(bin, ["tool", name, JSON.stringify(args)], {
      timeout: 60_000,
      maxBuffer: 1024 * 1024,
    });
    return (stdout || stderr || "完成").trim();
  } catch (err: any) {
    if (err?.code === "ENOENT") {
      throw new Error(`找不到 AiSiri CLI（${bin}）。请先构建 AiSiri，或设置 AISIRI_BIN 指向可执行文件。`);
    }
    throw new Error((err?.stderr || err?.message || String(err)).trim());
  }
}

type Params = Record<string, unknown>;

function macTool(
  name: string,
  label: string,
  description: string,
  properties: Params,
) {
  return defineTool({
    name: `mac_${name}`,
    label,
    description: `${description}（AiSiri / macOS）`,
    parameters: Type.Object(properties as any),
    async execute(_toolCallId, params) {
      const text = await runTool(name, params as Record<string, unknown>);
      return {
        content: [{ type: "text" as const, text }],
        details: { tool: name, args: params },
      };
    },
  });
}

const tools = [
  macTool("open_app", "Open App", "在 Mac 上打开应用程序", {
    name: Type.String({ description: "应用名称，如 计算器 / Google Chrome / 微信" }),
  }),
  macTool("quit_app", "Quit App", "退出应用程序", {
    name: Type.String({ description: "应用名称" }),
  }),
  macTool("open_url", "Open URL", "在默认浏览器打开网址", {
    url: Type.String({ description: "完整网址" }),
  }),
  macTool("web_search", "Web Search", "用浏览器搜索关键词", {
    query: Type.String({ description: "搜索词" }),
  }),
  macTool("run_shortcut", "Run Shortcut", "运行系统「快捷指令」", {
    name: Type.String({ description: "快捷指令名称" }),
    input: Type.Optional(Type.String({ description: "可选输入" })),
  }),
  macTool("list_shortcuts", "List Shortcuts", "列出本机快捷指令", {}),
  macTool("set_volume", "Set Volume", "设置系统音量 0-100", {
    level: Type.Integer({ description: "音量百分比" }),
  }),
  macTool("get_volume", "Get Volume", "获取当前系统音量", {}),
  macTool("set_brightness", "Set Brightness", "调节屏幕亮度", {
    direction: Type.String({ description: "up 或 down" }),
    steps: Type.Optional(Type.Integer({ description: "步数，默认 1" })),
  }),
  macTool("music_control", "Music Control", "控制「音乐」App", {
    action: Type.String({ description: "play/pause/playpause/next/previous" }),
    query: Type.Optional(Type.String({ description: "按名称播放的歌曲/艺人" })),
  }),
  macTool("now_playing", "Now Playing", "查看当前播放的歌曲", {}),
  macTool("create_reminder", "Create Reminder", "在「提醒事项」创建提醒", {
    title: Type.String({ description: "标题" }),
    notes: Type.Optional(Type.String({ description: "备注" })),
    due: Type.Optional(Type.String({ description: "截止时间 yyyy-MM-dd HH:mm" })),
  }),
  macTool("create_calendar_event", "Create Event", "在「日历」创建日程", {
    title: Type.String({ description: "标题" }),
    start: Type.String({ description: "开始时间 yyyy-MM-dd HH:mm" }),
    end: Type.String({ description: "结束时间 yyyy-MM-dd HH:mm" }),
  }),
  macTool("get_datetime", "Datetime", "获取当前日期时间", {}),
  macTool("system_info", "System Info", "获取电池/磁盘/运行时长", {}),
  macTool("clipboard_read", "Read Clipboard", "读取剪贴板内容", {}),
  macTool("clipboard_write", "Write Clipboard", "写入剪贴板", {
    text: Type.String({ description: "要写入的文本" }),
  }),
  macTool("speak", "Speak", "让电脑朗读一段文字", {
    text: Type.String({ description: "要朗读的文字" }),
  }),
  macTool("lock_screen", "Lock Screen", "锁定屏幕", {}),
  macTool("screenshot", "Screenshot", "截屏保存到桌面", {
    path: Type.Optional(Type.String({ description: "可选保存路径" })),
  }),
  macTool("type_text", "Type Text", "模拟键盘输入一段文字（需辅助功能权限）", {
    text: Type.String({ description: "要输入的文字" }),
  }),
  macTool("list_running_apps", "Running Apps", "列出正在运行的应用", {}),
  macTool("get_weather", "Weather", "查询城市天气", {
    city: Type.String({ description: "城市名，如 Beijing" }),
  }),
];

// 危险工具默认关闭，显式开启才注册
if (process.env.AISIRI_ENABLE_DANGEROUS === "1") {
  tools.push(
    macTool("shell_command", "Shell Command", "执行一条 shell 命令（危险）", {
      command: Type.String({ description: "命令" }),
    }),
    macTool("run_applescript", "Run AppleScript", "执行 AppleScript（危险）", {
      source: Type.String({ description: "AppleScript 源码" }),
    }),
  );
}

export default function (pi: ExtensionAPI) {
  for (const tool of tools) pi.registerTool(tool);
}
