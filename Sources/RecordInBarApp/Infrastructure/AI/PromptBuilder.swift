import Foundation

struct TopicSummarySnapshot: Sendable {
    let topicID: UUID
    let title: String
    let kindLabel: String
    let noteContents: [String]
}

struct PromptBuilder {
    static func buildSummaryMessages(for snapshot: TopicSummarySnapshot) -> [DeepSeekMessage] {
        let notesBody = snapshot.noteContents
            .map { "- \($0.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")

        let systemPrompt = """
        你是一个笔记整理助手。
        你的任务是仅根据用户提供的内容，做客观、克制、压缩性的总结。
        不要评价内容好坏，不要延伸推断，不要给建议，不要加入额外观点。
        输出只保留总结正文，使用 2 到 4 个自然段，每段 1 到 3 句。
        """

        let userPrompt = """
        标题：\(snapshot.title)
        类型：\(snapshot.kindLabel)

        内容：
        \(notesBody)
        """

        return [
            DeepSeekMessage(role: "system", content: systemPrompt),
            DeepSeekMessage(role: "user", content: userPrompt)
        ]
    }
}
