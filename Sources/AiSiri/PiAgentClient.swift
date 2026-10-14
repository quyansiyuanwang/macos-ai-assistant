import Foundation

/// 通过 stdin/stdout JSONL 驱动 `agent/server.mjs`（基于 pi-agent-core + pi-ai 的 Agent 运行时）。
final class PiAgentClient {
    var onDelta: ((String) -> Void)?
    var onTool: ((String, String) -> Void)?
    var onDone: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var buffer = Data()
    private let lock = NSLock()

    // MARK: - 可用性

    static func nodePath() -> String? {
        let candidates = ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node", "/opt/local/bin/node"]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) { return c }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let c = "\(dir)/node"
                if FileManager.default.isExecutableFile(atPath: c) { return c }
            }
        }
        return nil
    }

    static func serverPath() -> String? {
        let names = ["server.bundle.mjs", "server.mjs"]
        if let r = Bundle.main.resourceURL {
            for n in names {
                let p = r.appendingPathComponent("agent/\(n)").path
                if FileManager.default.fileExists(atPath: p) { return p }
            }
        }
        for dir in ["~/AiSiri/agent", "~/macos-ai-assistant/agent"] {
            for n in names {
                let p = NSString(string: "\(dir)/\(n)").expandingTildeInPath
                if FileManager.default.fileExists(atPath: p) { return p }
            }
        }
        return nil
    }

    static var isAvailable: Bool { nodePath() != nil && serverPath() != nil }

    // MARK: - 生命周期

    @discardableResult
    func start() -> Bool {
        if process != nil { return true }
        guard let node = PiAgentClient.nodePath(), let server = PiAgentClient.serverPath() else { return false }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: node)
        p.arguments = [server]
        var env = ProcessInfo.processInfo.environment
        env["AISIRI_BIN"] = NSString(string: "~/.local/bin/aisiri").expandingTildeInPath
        p.environment = env

        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        let inp = Pipe()
        p.standardInput = inp

        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty else { return }
            self?.append(data)
        }
        p.terminationHandler = { [weak self] _ in
            self?.process = nil
            self?.stdinHandle = nil
        }
        do { try p.run() } catch { return false }
        process = p
        stdinHandle = inp.fileHandleForWriting
        return true
    }

    func stop() {
        stdinHandle?.closeFile()
        process?.terminate()
        process = nil
        stdinHandle = nil
    }

    // MARK: - 命令

    func ask(_ text: String) { send(["type": "prompt", "message": text]) }
    func reset() { send(["type": "reset"]) }
    func abort() { send(["type": "abort"]) }

    func updateSettings(_ s: AppSettings) {
        send(["type": "set_config", "settings": [
            "base_url": s.baseURL,
            "api_key": s.apiKey,
            "model": s.model,
            "max_tokens": s.maxTokens,
            "temperature": s.temperature,
            "system_prompt": s.systemPrompt,
            "disabled_tools": s.disabledTools
        ]])
    }

    private func send(_ obj: [String: Any]) {
        guard let h = stdinHandle, let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        var line = data
        line.append(0x0A)
        lock.lock(); defer { lock.unlock() }
        try? h.write(contentsOf: line)
    }

    // MARK: - 读取

    private func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let idx = buffer.firstIndex(of: 0x0A) {
            let slice = buffer.subdata(in: buffer.startIndex..<idx)
            buffer.removeSubrange(buffer.startIndex...idx)
            if let s = String(data: slice, encoding: .utf8) { lines.append(s) }
        }
        lock.unlock()
        for line in lines { handle(line) }
    }

    private func handle(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case "delta":
                if let t = obj["text"] as? String { self.onDelta?(t) }
            case "tool_start":
                let name = obj["name"] as? String ?? ""
                let args = (obj["args"] as? [String: Any]).map { Self.describe($0) } ?? ""
                self.onTool?(name, args)
            case "done":
                self.onDone?(obj["text"] as? String ?? "")
            case "error":
                self.onError?(obj["message"] as? String ?? "未知错误")
            default:
                break
            }
        }
    }

    private static func describe(_ args: [String: Any]) -> String {
        guard !args.isEmpty else { return "" }
        if let d = try? JSONSerialization.data(withJSONObject: args),
           let s = String(data: d, encoding: .utf8) { return s }
        return ""
    }
}
