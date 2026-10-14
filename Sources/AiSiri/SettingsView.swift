import SwiftUI
import AVFoundation
import AppKit

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared

    var body: some View {
        TabView {
            ModelTab(store: store).tabItem { Label("模型", systemImage: "cpu") }
            VoiceTab(store: store).tabItem { Label("语音", systemImage: "waveform") }
            ChatTab(store: store).tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right") }
            BehaviorTab(store: store).tabItem { Label("行为", systemImage: "slider.horizontal.3") }
            ToolsTab(store: store).tabItem { Label("工具", systemImage: "wrench.and.screwdriver") }
            AboutTab().tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 580, height: 540)
    }
}

// MARK: - 模型

private struct ModelTab: View {
    @ObservedObject var store: SettingsStore
    @State private var testResult = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section("接口") {
                TextField("API 地址", text: $store.settings.baseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $store.settings.apiKey)
                    .textFieldStyle(.roundedBorder)
                TextField("模型", text: $store.settings.model)
                    .textFieldStyle(.roundedBorder)
                Text("任何 OpenAI 兼容端点都可用（DeepSeek / OpenAI / Ollama 等）")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
            Section("生成参数") {
                Stepper("最大 tokens：\(store.settings.maxTokens)", value: $store.settings.maxTokens, in: 256...131072, step: 256)
                HStack {
                    Text("温度：\(String(format: "%.1f", store.settings.temperature))")
                    Slider(value: $store.settings.temperature, in: 0...1.5, step: 0.1)
                }
            }
            Section("系统提示词") {
                TextEditor(text: $store.settings.systemPrompt)
                    .font(.system(size: 12))
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            }
            HStack {
                Button(testing ? "测试中…" : "测试连接") { test() }.disabled(testing)
                Text(testResult).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .padding(16)
    }

    private func test() {
        testing = true; testResult = ""
        let s = store.settings
        Task {
            do {
                let client = DeepSeekClient(s)
                let msg = try await client.chat(messages: [["role": "user", "content": "ping，只回复 pong"]], tools: [])
                let text = (msg["content"] as? String) ?? "(空)"
                testResult = "✅ 连接成功：\(text.prefix(30))"
            } catch {
                testResult = "❌ \(error.localizedDescription)"
            }
            testing = false
        }
    }
}

// MARK: - 语音

private struct VoiceTab: View {
    @ObservedObject var store: SettingsStore

    private var voices: [AVSpeechSynthesisVoice] {
        let prefix = String(store.settings.voiceLanguage.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
    }

    var body: some View {
        Form {
            Section("输出") {
                Toggle("朗读回答", isOn: $store.settings.voiceEnabled)
                Picker("语言", selection: $store.settings.voiceLanguage) {
                    Text("中文（普通话）").tag("zh-CN")
                    Text("中文（粤语）").tag("zh-HK")
                    Text("English (US)").tag("en-US")
                    Text("日本語").tag("ja-JP")
                }
                Picker("音色", selection: $store.settings.voiceName) {
                    Text("默认").tag("")
                    ForEach(voices, id: \.identifier) { v in
                        Text(v.name).tag(v.identifier)
                    }
                }
                HStack {
                    Text("语速")
                    Slider(value: $store.settings.voiceRate, in: 0.3...0.8)
                }
                HStack {
                    Text("音量")
                    Slider(value: $store.settings.voiceVolume, in: 0...1)
                }
                Button("试听") {
                    Speaker.shared.configure(store.settings)
                    Speaker.shared.say("你好，我是 AiSiri，这是一段试听。")
                }
            }
            Section("输入") {
                HStack {
                    Text("说完静音 \(String(format: "%.1f", store.settings.silenceTimeout)) 秒自动结束")
                    Slider(value: $store.settings.silenceTimeout, in: 0.5...5, step: 0.1)
                }
                HStack {
                    Text("一直没说话 \(Int(store.settings.noSpeechTimeout)) 秒放弃")
                    Slider(value: $store.settings.noSpeechTimeout, in: 3...30, step: 1)
                }
                Toggle("说完自动发送（不必按回车）", isOn: $store.settings.autoSendOnSilence)
            }
        }
        .padding(16)
    }
}

// MARK: - 对话

private struct ChatTab: View {
    @ObservedObject var store: SettingsStore
    var body: some View {
        Form {
            Section("对话行为") {
                Toggle("连续对话（回答朗读完自动接着听）", isOn: $store.settings.continuousMode)
                Toggle("显示工具调用过程", isOn: $store.settings.showToolCalls)
            }
            Section {
                Text("提示：连续对话适合纯语音一问一答；关闭窗口会自动停止接听。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .padding(16)
    }
}

// MARK: - 行为

private struct BehaviorTab: View {
    @ObservedObject var store: SettingsStore
    var body: some View {
        Form {
            Section("快捷键") {
                Picker("唤起语音", selection: $store.settings.hotkey) {
                    ForEach(HotKeyManager.presets, id: \.value) { p in
                        Text(p.label).tag(p.value)
                    }
                }
            }
            Section("窗口与启动") {
                Toggle("窗口始终置顶", isOn: $store.settings.alwaysOnTop)
                Toggle("开机自动启动", isOn: $store.settings.launchAtLogin)
            }
            Section {
                HStack {
                    Button("打开配置文件") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: store.path)])
                    }
                    Button("恢复默认设置") { store.reset() }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - 工具

private struct ToolsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关闭不想让模型调用的工具（其余全部启用）。危险工具建议保持关闭：shell_command、run_applescript。")
                .font(.system(size: 11)).foregroundColor(.secondary)
            List {
                ForEach(ToolRunner.catalog(), id: \.name) { item in
                    Toggle(isOn: binding(item.name)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).font(.system(size: 12, weight: .medium))
                            Text(item.desc).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func binding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { !store.settings.disabledTools.contains(name) },
            set: { on in
                var d = store.settings.disabledTools
                if on { d.removeAll { $0 == name } }
                else if !d.contains(name) { d.append(name) }
                store.settings.disabledTools = d
            }
        )
    }
}

// MARK: - 关于

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "brain.head.profile").font(.system(size: 44))
            Text("AiSiri").font(.title2).bold()
            Text("菜单栏语音助手，由大模型驱动，可操作 macOS").font(.system(size: 12)).foregroundColor(.secondary)
            Text("开源项目 · MIT License").font(.system(size: 11)).foregroundColor(.secondary)
            Divider().frame(width: 240)
            Text("快捷键 ⌥Space 唤起 · 说话 · 回车发送").font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
