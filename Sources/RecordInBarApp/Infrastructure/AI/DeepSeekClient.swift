import Foundation

struct DeepSeekMessage: Codable {
    let role: String
    let content: String
}

struct DeepSeekSummaryResult {
    let summaryText: String
    let keyPointsText: String
    let questionsText: String
    let nextIdeasText: String
}

enum DeepSeekClientError: LocalizedError {
    case missingAPIKey
    case emptyNotes
    case invalidResponse
    case api(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "DeepSeek API Key is missing."
        case .emptyNotes:
            "Add at least one note before running AI summary."
        case .invalidResponse:
            "DeepSeek returned an unexpected response."
        case let .api(statusCode, message):
            "DeepSeek API error (\(statusCode)): \(message)"
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

        return Self.parseSummarySections(from: content)
    }

    private static func parseSummarySections(from content: String) -> DeepSeekSummaryResult {
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var currentSection = "summary"
        var sections: [String: [String]] = [
            "summary": [],
            "keyPoints": [],
            "questions": [],
            "nextIdeas": []
        ]

        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.contains("one-sentence summary") || lowercased.contains("summary") {
                currentSection = "summary"
                continue
            }

            if lowercased.contains("key points") {
                currentSection = "keyPoints"
                continue
            }

            if lowercased.contains("open questions") || lowercased.contains("questions") {
                currentSection = "questions"
                continue
            }

            if lowercased.contains("next ideas") || lowercased.contains("ideas") {
                currentSection = "nextIdeas"
                continue
            }

            sections[currentSection, default: []].append(line)
        }

        return DeepSeekSummaryResult(
            summaryText: sections["summary"]?.joined(separator: "\n").nilIfEmpty ?? content,
            keyPointsText: sections["keyPoints"]?.joined(separator: "\n").nilIfEmpty ?? "No key points returned.",
            questionsText: sections["questions"]?.joined(separator: "\n").nilIfEmpty ?? "No open questions returned.",
            nextIdeasText: sections["nextIdeas"]?.joined(separator: "\n").nilIfEmpty ?? "No next ideas returned."
        )
    }
}

private struct ChatCompletionRequest: Codable {
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

private struct ThinkingPayload: Codable {
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
