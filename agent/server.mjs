/**
 * AiSiri agent runtime.
 *
 * Built directly on pi sub-packages:
 *   - @earendil-works/pi-agent-core : Agent (transcript, tool loop, lifecycle events)
 *   - @earendil-works/pi-ai         : provider stream (OpenAI-compatible) 
 *
 * The Swift app spawns this process and talks JSONL over stdin/stdout.
 *
 * Commands (stdin):  {type:"prompt", message} | {type:"reset"} | {type:"abort"} | {type:"set_config", settings}
 * Events (stdout):   {type:"ready"} | {type:"delta", text} | {type:"tool_start", name, args}
 *                    {type:"tool_end", name} | {type:"done", text} | {type:"error", message}
 */

import { Agent } from "@earendil-works/pi-agent-core";
import { streamSimple } from "@earendil-works/pi-ai/api/openai-completions";
import { Type } from "typebox";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { homedir } from "node:os";
import { join } from "node:path";
import { readFileSync } from "node:fs";

const exec = promisify(execFile);
const BIN = process.env.AISIRI_BIN || join(homedir(), ".local", "bin", "aisiri");

// ---- 配置：读 ~/.config/aisiri/config.json，可被 AISIRI_AGENT_CONFIG 覆盖 ----
function loadSettings() {
  let s = {};
  try {
    s = JSON.parse(readFileSync(join(homedir(), ".config", "aisiri", "config.json"), "utf8"));
  } catch {}
  if (process.env.AISIRI_AGENT_CONFIG) {
    try { s = { ...s, ...JSON.parse(process.env.AISIRI_AGENT_CONFIG) }; } catch {}
  }
  s.base_url ||= "https://api.deepseek.com";
  s.api_key ||= "";
  s.model ||= "deepseek-flash";
  s.max_tokens ||= 8192;
  s.temperature ??= 0.7;
  s.system_prompt ||= "你是运行在用户 Mac 上的智能助手。可调用工具操作电脑。回复简洁，适合语音朗读。";
  s.disabled_tools ||= [];
  return s;
}

let settings = loadSettings();

function makeModel() {
  return {
    id: settings.model,
    name: settings.model,
    api: "openai-completions",
    provider: "deepseek",
    baseUrl: settings.base_url,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    reasoning: false,
    contextWindow: 128000,
    maxTokens: settings.max_tokens,
  };
}

// ---- 工具：调用 aisiri CLI，复用 Swift 端实现 ----
async function runTool(name, args) {
  const { stdout, stderr } = await exec(BIN, ["tool", name, JSON.stringify(args ?? {})], {
    timeout: 60_000,
    maxBuffer: 1024 * 1024,
  });
  return (stdout || stderr || "完成").trim();
}

function macTool(name, label, description, properties) {
  return {
    name,
    label,
    description,
    parameters: Type.Object(properties),
    async execute(_id, params) {
      try {
        const text = await runTool(name, params);
        return { content: [{ type: "text", text }], details: { tool: name } };
      } catch (err) {
        return { content: [{ type: "text", text: String(err?.message || err) }], details: { tool: name }, isError: true };
      }
    },
  };
}

const S = (d) => Type.String({ description: d });
const I = (d) => Type.Integer({ description: d });
const O = (t) => Type.Optional(t);

const allTools = [
  macTool("open_app", "Open App", "打开应用程序", { name: S("应用名称") }),
  macTool("quit_app", "Quit App", "退出应用程序", { name: S("应用名称") }),
  macTool("open_url", "Open URL", "打开网址", { url: S("完整网址") }),
  macTool("web_search", "Web Search", "搜索关键词", { query: S("搜索词") }),
  macTool("run_shortcut", "Run Shortcut", "运行快捷指令", { name: S("名称"), input: O(S("输入")) }),
  macTool("list_shortcuts", "List Shortcuts", "列出快捷指令", {}),
  macTool("set_volume", "Set Volume", "设置音量 0-100", { level: I("音量") }),
  macTool("get_volume", "Get Volume", "获取音量", {}),
  macTool("set_brightness", "Set Brightness", "调亮度", { direction: S("up/down"), steps: O(I("步数")) }),
  macTool("music_control", "Music", "控制音乐", { action: S("play/pause/next/previous"), query: O(S("歌曲")) }),
  macTool("now_playing", "Now Playing", "当前播放", {}),
  macTool("create_reminder", "Reminder", "创建提醒", { title: S("标题"), notes: O(S("备注")), due: O(S("yyyy-MM-dd HH:mm")) }),
  macTool("create_calendar_event", "Calendar", "创建日程", { title: S("标题"), start: S("开始"), end: S("结束") }),
  macTool("get_datetime", "Datetime", "当前时间", {}),
  macTool("system_info", "System Info", "系统信息", {}),
  macTool("clipboard_read", "Read Clipboard", "读剪贴板", {}),
  macTool("clipboard_write", "Write Clipboard", "写剪贴板", { text: S("文本") }),
  macTool("speak", "Speak", "朗读文字", { text: S("文本") }),
  macTool("lock_screen", "Lock Screen", "锁屏", {}),
  macTool("screenshot", "Screenshot", "截屏", { path: O(S("路径")) }),
  macTool("type_text", "Type Text", "模拟输入", { text: S("文本") }),
  macTool("list_running_apps", "Running Apps", "运行中的应用", {}),
  macTool("get_weather", "Weather", "天气", { city: S("城市") }),
];

function activeTools() {
  const disabled = new Set(settings.disabled_tools || []);
  return allTools.filter((t) => !disabled.has(t.name));
}

// ---- Agent ----
const agent = new Agent({
  initialState: {
    systemPrompt: settings.system_prompt,
    model: makeModel(),
    tools: activeTools(),
    messages: [],
  },
  streamFn: (model, context, options) =>
    streamSimple(model, context, { ...options, apiKey: settings.api_key, temperature: settings.temperature }),
  getApiKey: async () => settings.api_key,
});

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

function lastAssistantText(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m?.role === "assistant" && Array.isArray(m.content)) {
      return m.content.filter((c) => c.type === "text").map((c) => c.text).join("");
    }
  }
  return "";
}

agent.subscribe((event) => {
  if (event.type === "message_update" && event.assistantMessageEvent?.type === "text_delta") {
    send({ type: "delta", text: event.assistantMessageEvent.delta });
  } else if (event.type === "tool_execution_start") {
    send({ type: "tool_start", name: event.toolName, args: event.args });
  } else if (event.type === "tool_execution_end") {
    send({ type: "tool_end", name: event.toolName });
  } else if (event.type === "agent_end") {
    send({ type: "done", text: lastAssistantText(event.messages) });
  }
});

// ---- stdio JSONL（手动按 \n 分帧，避免 readline 误切 U+2028/2029）----
let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  let idx;
  while ((idx = buffer.indexOf("\n")) >= 0) {
    let line = buffer.slice(0, idx);
    buffer = buffer.slice(idx + 1);
    if (line.endsWith("\r")) line = line.slice(0, -1);
    if (line.trim()) handle(line);
  }
});

async function handle(line) {
  let cmd;
  try { cmd = JSON.parse(line); } catch { return; }
  try {
    if (cmd.type === "prompt") {
      await agent.prompt(cmd.message);
    } else if (cmd.type === "reset") {
      agent.reset();
      send({ type: "reset_ok" });
    } else if (cmd.type === "abort") {
      agent.abort();
    } else if (cmd.type === "set_config") {
      settings = { ...settings, ...(cmd.settings || {}) };
      agent.state.model = makeModel();
      agent.state.tools = activeTools();
      send({ type: "config_ok" });
    }
  } catch (err) {
    send({ type: "error", message: String(err?.message || err) });
  }
}

process.stdin.on("end", () => {
  // stdin 关闭（客户端退出）：等当前运行结束后退出
  Promise.resolve(agent.waitForIdle()).finally(() => process.exit(0));
});

send({ type: "ready" });
