import SwiftUI

struct Bubble: Identifiable {
    let id = UUID()
    let role: String   // user / assistant / tool
    let text: String
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var bubbles: [Bubble] = []
    @Published var input = ""
    @Published var busy = false
    @Published var isRecording = false
    @Published var streaming = ""
    @Published var liveTranscript = ""
    /// 窗口是否可见（不可见时不自动接听）
    @Published var windowVisible = false

    let agent = Agent()
    let speech = SpeechRecognizer()

    private var settings: AppSettings { SettingsStore.shared.settings }

    init() {
        agent.onDelta = { [weak self] chunk in
            DispatchQueue.main.async { self?.streaming += chunk }
        }
        agent.onTool = { [weak self] name, result in
            DispatchQueue.main.async {
                guard let self else { return }
                if !self.streaming.isEmpty {
                    self.bubbles.append(Bubble(role: "assistant", text: self.streaming))
                    self.streaming = ""
                }
                if SettingsStore.shared.settings.showToolCalls {
                    self.bubbles.append(Bubble(role: "tool", text: "🔧 \(name) → \(result)"))
                }
            }
        }
        // 听写只更新「聆听中」预览，不碰输入框，避免覆盖你已编辑的内容
        speech.onUpdate = { [weak self] t in
            self?.liveTranscript = t
        }
        speech.onStateChange = { [weak self] recording in
            guard let self else { return }
            self.isRecording = recording
            if !recording {
                self.commitTranscript()
                if SettingsStore.shared.settings.autoSendOnSilence && !self.busy {
                    self.send()
                }
            }
        }
        // 一段回答朗读完后，若开启连续对话则自动接着听
        Speaker.shared.onFinish = { [weak self] in
            guard let self else { return }
            guard SettingsStore.shared.settings.continuousMode, self.windowVisible, !self.busy else { return }
            self.startVoice()
        }
    }

    /// 录音结束：把听写结果追加到输入框（不覆盖已有/已编辑文本）
    func commitTranscript() {
        let t = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        guard !t.isEmpty else { return }
        if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input = t
        } else if input.hasSuffix(" ") || input.hasSuffix("\n") {
            input += t
        } else {
            input += " " + t
        }
    }

    /// 回车：若在录音则先结束并并入文字，再发送
    func submit() {
        if isRecording { speech.stop() }
        send()
    }

    func send() {
        if isRecording { speech.stop() }          // 发送前强制关麦克风
        Speaker.shared.stop()
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        input = ""
        bubbles.append(Bubble(role: "user", text: text))
        busy = true
        streaming = ""
        agent.settings = settings
        Speaker.shared.configure(settings)

        Task {
            do {
                let answer = try await agent.ask(text)
                if !streaming.isEmpty {
                    bubbles.append(Bubble(role: "assistant", text: streaming))
                    streaming = ""
                } else if !answer.isEmpty {
                    bubbles.append(Bubble(role: "assistant", text: answer))
                }
                if settings.voiceEnabled { Speaker.shared.say(answer) }
            } catch {
                streaming = ""
                bubbles.append(Bubble(role: "assistant", text: "⚠️ \(error.localizedDescription)"))
            }
            busy = false
            if settings.continuousMode && !settings.voiceEnabled {
                startVoice()
            }
        }
    }

    func toggleMic() {
        if isRecording { speech.stop() } else { startVoice() }
    }

    func startVoice() {
        guard !isRecording else { return }
        Speaker.shared.stop()        // 打断正在朗读的回答
        liveTranscript = ""
        speech.applySettings(settings)
        speech.requestPermission { [weak self] ok in
            guard let self else { return }
            if ok {
                self.speech.start()
            } else {
                self.bubbles.append(Bubble(role: "assistant", text: "⚠️ 需要「麦克风」和「语音识别」权限，请在 系统设置 → 隐私与安全性 中授权 AiSiri。"))
            }
        }
    }

    func clear() {
        speech.stop()
        bubbles.removeAll()
        streaming = ""
        liveTranscript = ""
        agent.settings = settings
        agent.reset()
    }
}

struct ChatView: View {
    @ObservedObject var model: ChatModel
    @ObservedObject var store = SettingsStore.shared
    var onOpenSettings: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messages
            Divider()
            inputBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
            Text("AiSiri").font(.headline)
            Spacer()
            Toggle("朗读", isOn: $store.settings.voiceEnabled)
                .toggleStyle(.switch).controlSize(.mini)
            Toggle("连续", isOn: $store.settings.continuousMode)
                .toggleStyle(.switch).controlSize(.mini)
                .help("开启后：回答朗读完自动接着听，实现纯语音一问一答")
            Button { onOpenSettings() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless).help("设置")
            Button { model.clear() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("清空对话")
        }
        .padding(10)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if model.bubbles.isEmpty && model.streaming.isEmpty {
                        Text("你好，我是 AiSiri。\n直接说话或打字即可，我由大模型驱动，也能操作这台 Mac：\n· 打开计算器 / 播放周杰伦\n· 音量调到 30 / 明天 9 点提醒我开会\n· 查电池 / 截个屏 / 读剪贴板")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    }
                    ForEach(model.bubbles) { b in
                        row(b.id, b.role, b.text)
                    }
                    if !model.streaming.isEmpty {
                        row("streaming", "assistant", model.streaming)
                    }
                    if model.busy && model.streaming.isEmpty {
                        HStack { ProgressView().controlSize(.small); Text("思考中…").font(.system(size: 12)).foregroundColor(.secondary); Spacer() }
                    }
                }
                .padding(10)
            }
            .onChange(of: model.bubbles.count) { _ in
                if let last = model.bubbles.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            .onChange(of: model.streaming) { _ in
                withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
            }
        }
    }

    private func row(_ id: AnyHashable, _ role: String, _ text: String) -> some View {
        HStack {
            if role == "user" { Spacer(minLength: 40) }
            Text(text)
                .font(.system(size: 13))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(color(role))
                .foregroundColor(role == "user" ? .white : .primary)
                .cornerRadius(12)
                .textSelection(.enabled)
            if role != "user" { Spacer(minLength: 40) }
        }
        .id(id)
    }

    private var inputBar: some View {
        VStack(spacing: 4) {
            if model.isRecording {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill").foregroundColor(.red)
                    Text(model.liveTranscript.isEmpty ? "正在聆听…" : model.liveTranscript)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
            }
            HStack(spacing: 6) {
                Button { model.toggleMic() } label: {
                    Image(systemName: model.isRecording ? "mic.fill" : "mic")
                        .foregroundColor(model.isRecording ? .red : .primary)
                }
                .buttonStyle(.borderless)
                .help("点击说话；再次点击结束（结束不自动发送）")

                TextField(model.isRecording ? "录音中，回车结束并发送" : "输入，或按快捷键说话", text: $model.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .focused($focused)
                    .onSubmit { model.submit() }

                Button("发送") { model.submit() }
                    .disabled(model.busy || (model.input.trimmingCharacters(in: .whitespaces).isEmpty && !model.isRecording))
            }
            .padding(10)
        }
    }

    private func color(_ role: String) -> Color {
        switch role {
        case "user": return .accentColor
        case "tool": return Color.gray.opacity(0.15)
        default: return Color.gray.opacity(0.12)
        }
    }
}
