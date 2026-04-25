import Foundation

struct DeepSeekMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct DeepSeekSummaryResult: Sendable {
    let summaryText: String
}

enum DeepSeekClientError: LocalizedError {
    case missingAPIKey
    case emptyNotes
    case invalidResponse
    case api(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "缺少 DeepSeek API Key。"
        case .emptyNotes:
            "请先至少输入一条笔记，再执行 AI 总结。"
        case .invalidResponse:
            "DeepSeek 返回了无法识别的结果。"
        case let .api(statusCode, message):
            "DeepSeek API 错误（\(statusCode)）：\(message)"
        }
    }
}

struct DeepSeekClient {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.deepseek.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func validateAPIKey(_ apiKey: String) async throws {
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw DeepSeekClientError.missingAPIKey
        }

        var request = URLRequest(url: baseURL.appending(path: "/models"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw DeepSeekClientError.api(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? "Unknown API error"
            )
        }
    }

    func generateSummary(
        snapshot: TopicSummarySnapshot,
        apiKey: String,
        model: String,
        thinkingEnabled: Bool,
        reasoningEffort: String
    ) async throws -> DeepSeekSummaryResult {
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw DeepSeekClientError.missingAPIKey
        }

        guard !snapshot.noteContents.isEmpty else {
            throw DeepSeekClientError.emptyNotes
        }

        let payload = ChatCompletionRequest(
            model: model,
            messages: PromptBuilder.buildSummaryMessages(for: snapshot),
            thinking: thinkingEnabled ? ThinkingPayload(type: "enabled") : nil,
            reasoningEffort: reasoningEffort,
            stream: false
        )

        var request = URLRequest(url: baseURL.appending(path: "/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw DeepSeekClientError.api(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? "Unknown API error"
            )
        }

        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw DeepSeekClientError.invalidResponse
        }

        return DeepSeekSummaryResult(summaryText: Self.sanitizeSummary(content))
    }

    private static func sanitizeSummary(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let exactPrefixes = [
            "以下是总结：",
            "以下是总结:",
            "总结如下：",
            "总结如下:",
            "内容总结：",
            "内容总结:",
            "总结：",
            "总结:",
            "摘要：",
            "摘要:"
        ]

        for prefix in exactPrefixes where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lines = text
            .components(separatedBy: .newlines)
            .drop(while: { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty || Self.isBoilerplateHeading(trimmed)
            })

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isBoilerplateHeading(_ line: String) -> Bool {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = [
            "以下是总结",
            "总结如下",
            "总结",
            "摘要",
            "内容总结"
        ]
        return candidates.contains(normalized)
    }
}

private struct ChatCompletionRequest: Codable, Sendable {
    let model: String
    let messages: [DeepSeekMessage]
    let thinking: ThinkingPayload?
    let reasoningEffort: String
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case thinking
        case reasoningEffort = "reasoning_effort"
        case stream
    }
}

private struct ThinkingPayload: Codable, Sendable {
    let type: String
}

private struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }

        let index: Int
        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorEnvelope: Codable {
    struct APIError: Codable {
        let message: String
    }

    let error: APIError
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
