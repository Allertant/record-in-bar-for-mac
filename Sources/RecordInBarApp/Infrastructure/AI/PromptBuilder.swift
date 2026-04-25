import Foundation

struct TopicSummarySnapshot: Sendable {
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
        You are an analysis assistant for a personal note-taking app.
        Summarize the user's notes into exactly four sections:
        1. One-sentence Summary
        2. Key Points
        3. Open Questions
        4. Next Ideas
        Keep the output concise and structured.
        """

        let userPrompt = """
        Topic Title: \(snapshot.title)
        Topic Type: \(snapshot.kindLabel)

        Notes:
        \(notesBody)
        """

        return [
            DeepSeekMessage(role: "system", content: systemPrompt),
            DeepSeekMessage(role: "user", content: userPrompt)
        ]
    }
}
