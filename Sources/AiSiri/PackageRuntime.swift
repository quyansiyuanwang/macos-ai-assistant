import Foundation
import PiAI
import PiAgentCore

/// 基于 Swift 包（PiAI + PiAgentCore）的运行时装配。
///
/// 运行期完全不依赖 Node.js：`OpenAICompletionsProvider` 直接发起 HTTPS 流式
/// 请求，`PiAgentCore.Agent` 负责「助手 ↔ 工具」循环，本机工具通过
/// ``ToolRunner/packageTools(disabled:)`` 注入。
enum PackageRuntime {

    /// 依据 App 设置构造 PiAI 模型描述。
    static func makeModel(_ settings: AppSettings) -> Model {
        Model(
            id: settings.model,
            name: settings.model,
            api: "openai-completions",
            provider: "deepseek",
            baseURL: settings.baseURL,
            contextWindow: 128_000,
            maxTokens: settings.maxTokens
        )
    }

    /// 构造一个可直接 `prompt` 的 `Agent`（含工具与系统提示）。
    static func makeAgent(_ settings: AppSettings) -> Agent {
        Agent(options: AgentOptions(
            systemPrompt: settings.systemPrompt,
            model: makeModel(settings),
            tools: ToolRunner.packageTools(disabled: settings.disabledTools),
            provider: SettingsProvider(
                provider: OpenAICompletionsProvider(),
                temperature: settings.temperature,
                maxTokens: settings.maxTokens
            ),
            apiKey: settings.apiKey
        ))
    }

    // MARK: - 事件格式化

    /// 从内容块中拼接纯文本。
    static func text(of blocks: [ContentBlock]) -> String {
        blocks.compactMap { block -> String? in
            if case .text(let content) = block { return content.text }
            return nil
        }.joined()
    }

    /// 返回一段 run 中最后一条非空 assistant 文本。
    static func finalAnswer(in messages: [Message]) -> String {
        for message in messages.reversed() {
            if case .assistant(let assistant) = message {
                let text = text(of: assistant.content)
                if !text.isEmpty { return text }
            }
        }
        return ""
    }

    /// 把工具参数 JSON 渲染成单行（空对象返回空串）。
    static func describe(_ value: JSONValue) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8), text != "{}" else { return "" }
        return text
    }
}

/// 把应用设置里的 `temperature` / `maxTokens` 注入每次请求。
///
/// `PiAgentCore.AgentOptions` 目前只透传 `apiKey`，因此在 provider 层包一层
/// 补齐生成参数，保证「设置」里的参数对 Swift 包运行时同样生效。
struct SettingsProvider: ChatProvider {
    let provider: OpenAICompletionsProvider
    let temperature: Double?
    let maxTokens: Int?

    func stream(
        model: Model,
        context: ChatContext,
        options: ChatOptions
    ) -> AsyncThrowingStream<AssistantMessageEvent, any Error> {
        var options = options
        if let temperature { options.temperature = temperature }
        if let maxTokens { options.maxTokens = maxTokens }
        return provider.stream(model: model, context: context, options: options)
    }
}
