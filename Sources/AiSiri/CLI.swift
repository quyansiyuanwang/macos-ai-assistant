import Foundation

/// 命令行入口，供「快捷指令 / Siri」调用：`AiSiri ask "打开计算器"`
enum CLI {
    static func run(_ args: [String]) {
        switch args.first {
        case "ask":
            ask(args.dropFirst().joined(separator: " "))
        case "tool":
            // aisiri tool <name> [json-args]  —— 直接执行某个本机工具
            let rest = Array(args.dropFirst())
            guard let name = rest.first else { print("用法: aisiri tool <name> [json]"); return }
            let json = rest.count > 1 ? rest[1] : "{}"
            let a = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
            print(ToolRunner.run(name: name, args: a))
        case "tools":
            for t in ToolRunner.catalog() { print("\(t.name)\t\(t.desc)") }
        case "agent":
            runPiAgent(args.dropFirst().joined(separator: " "))
        case "help", "--help", "-h":
            print("""
            AiSiri 命令行
              AiSiri ask "问题"          调用大模型并执行本机操作，结果打印到 stdout
              echo "问题" | AiSiri ask   从标准输入读取问题
              AiSiri tool <name> [json]  直接执行某个本机工具
              AiSiri tools               列出全部工具
              AiSiri agent "问题"        用 pi Agent 运行时对话（pi-agent-core + pi-ai）
            """)
        default:
            ask(args.joined(separator: " "))
        }
    }

    static func ask(_ prompt: String) {
        var text = prompt
        var speak = false
        if text.hasPrefix("--speak ") {
            speak = true
            text = String(text.dropFirst("--speak ".count))
        }
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            text = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !text.isEmpty else { print("缺少输入"); return }

        let sem = DispatchSemaphore(value: 0)
        let agent = Agent()
        agent.onTool = { name, result in
            FileHandle.standardError.write(Data("[tool] \(name) → \(result)\n".utf8))
        }
        Task {
            do {
                let answer = try await agent.ask(text)
                print(answer)
                if speak { ToolRunner.sh("say \(ToolRunner.q(answer))") }
            } catch {
                FileHandle.standardError.write(Data("错误: \(error.localizedDescription)\n".utf8))
            }
            sem.signal()
        }
        sem.wait()
    }

    /// 使用 pi Agent 运行时（agent/server.mjs）执行一次对话
    static func runPiAgent(_ prompt: String) {
        var text = prompt
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            text = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !text.isEmpty else { print("缺少输入"); return }
        guard PiAgentClient.isAvailable else { print("pi 运行时不可用（需要 Node.js 与 agent/ 依赖）"); return }

        let client = PiAgentClient()
        var finished = false
        client.onDelta = { chunk in FileHandle.standardOutput.write(Data(chunk.utf8)) }
        client.onTool = { name, args in
            FileHandle.standardError.write(Data("[tool] \(name) \(args)\n".utf8))
        }
        client.onDone = { _ in finished = true }
        client.onError = { msg in
            FileHandle.standardError.write(Data("错误: \(msg)\n".utf8))
            finished = true
        }
        guard client.start() else { print("无法启动 pi 运行时"); return }
        client.ask(text)
        while !finished {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        client.stop()
        print("")
    }
}
