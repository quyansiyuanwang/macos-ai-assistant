import Foundation

/// 全部可配置项。缺字段时用默认值，保证向后兼容。
struct AppSettings: Codable, Equatable {
    // 模型
    var baseURL = "https://api.deepseek.com"
    var apiKey = ""
    var model = "deepseek-flash"
    var maxTokens = 8192
    var temperature = 0.7
    var systemPrompt = AppSettings.defaultSystemPrompt

    // 语音输出
    var voiceEnabled = true
    var voiceLanguage = "zh-CN"
    var voiceName = ""
    var voiceRate = 0.5
    var voiceVolume = 1.0

    // 语音输入 / 对话
    var silenceTimeout = 1.5
    var noSpeechTimeout = 8.0
    var autoSendOnSilence = false
    var continuousMode = false

    // 界面 / 行为
    var hotkey = "option+space"
    var showToolCalls = true
    var alwaysOnTop = false
    var launchAtLogin = true
    /// Agent 运行时：auto / package / builtin（不再有 Node）
    var agentRuntime = "auto"
    var disabledTools: [String] = []

    static let defaultSystemPrompt = """
    你是运行在用户 Mac 上的智能助手「AiSiri」。你既可以正常聊天，也可以通过工具操作这台电脑。
    规则：
    1. 用户要求操作电脑（打开/关闭应用、控制音乐、音量、提醒、日历、运行快捷指令、执行 AppleScript、查询电池/时间/剪贴板等）时，先调用相应工具，再根据工具返回结果用简短中文回复。
    2. 涉及需要用户提供但缺失的参数时，先询问用户，不要瞎猜。
    3. 执行危险操作（删除文件、关机、清空剪贴板等）前先确认。
    4. 回复简洁自然，适合语音朗读（不要用 Markdown 表格、代码块、过多 emoji）。
    5. 不确定时如实说明，不要编造工具执行结果。
    """

    init() {}

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url", apiKey = "api_key", model
        case maxTokens = "max_tokens", temperature
        case systemPrompt = "system_prompt"
        case voiceEnabled = "voice_enabled", voiceLanguage = "voice_language"
        case voiceName = "voice_name", voiceRate = "voice_rate", voiceVolume = "voice_volume"
        case silenceTimeout = "silence_timeout", noSpeechTimeout = "no_speech_timeout"
        case autoSendOnSilence = "auto_send_on_silence", continuousMode = "continuous_mode"
        case hotkey, showToolCalls = "show_tool_calls"
        case alwaysOnTop = "always_on_top", launchAtLogin = "launch_at_login"
        case agentRuntime = "agent_runtime"
        case disabledTools = "disabled_tools"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.deepseek.com"
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? "deepseek-flash"
        maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 8192
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.7
        systemPrompt = try c.decodeIfPresent(String.self, forKey: .systemPrompt) ?? AppSettings.defaultSystemPrompt
        voiceEnabled = try c.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? true
        voiceLanguage = try c.decodeIfPresent(String.self, forKey: .voiceLanguage) ?? "zh-CN"
        voiceName = try c.decodeIfPresent(String.self, forKey: .voiceName) ?? ""
        voiceRate = try c.decodeIfPresent(Double.self, forKey: .voiceRate) ?? 0.5
        voiceVolume = try c.decodeIfPresent(Double.self, forKey: .voiceVolume) ?? 1.0
        silenceTimeout = try c.decodeIfPresent(Double.self, forKey: .silenceTimeout) ?? 1.5
        noSpeechTimeout = try c.decodeIfPresent(Double.self, forKey: .noSpeechTimeout) ?? 8.0
        autoSendOnSilence = try c.decodeIfPresent(Bool.self, forKey: .autoSendOnSilence) ?? false
        continuousMode = try c.decodeIfPresent(Bool.self, forKey: .continuousMode) ?? false
        hotkey = try c.decodeIfPresent(String.self, forKey: .hotkey) ?? "option+space"
        showToolCalls = try c.decodeIfPresent(Bool.self, forKey: .showToolCalls) ?? true
        alwaysOnTop = try c.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? false
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        agentRuntime = try c.decodeIfPresent(String.self, forKey: .agentRuntime) ?? "auto"
        // 兼容旧配置：pi 运行时（Node 子进程）已由内建 Swift 包取代
        if agentRuntime == "pi" { agentRuntime = "package" }
        disabledTools = try c.decodeIfPresent([String].self, forKey: .disabledTools) ?? []
    }
}

/// 配置读写（~/.config/aisiri/config.json），改动即存盘。
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var settings: AppSettings {
        didSet { save() }
    }
    let path: String

    private init() {
        path = NSString(string: "~/.config/aisiri/config.json").expandingTildeInPath
        if let data = FileManager.default.contents(atPath: path),
           let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = s
        } else {
            settings = AppSettings()
        }
    }

    func save() {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(settings) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    func reset() { settings = AppSettings() }
}
