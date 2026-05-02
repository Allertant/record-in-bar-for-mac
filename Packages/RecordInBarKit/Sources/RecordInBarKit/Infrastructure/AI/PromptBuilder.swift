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
        你的唯一任务是：仅根据用户提供的内容，输出一段纯总结正文。
        严格禁止输出以下任何内容：
        1. 标题
        2. 小节名
        3. 项目符号
        4. 编号
        5. 开场白
        6. 结束语
        7. “以下是总结”“总结如下”“总结：”之类提示语
        8. 建议、评价、推断、延伸观点
        9. 任何不属于总结正文的附加文字
        输出要求：
        - 只输出最终总结内容本身
        - 不要使用 markdown
        - 不要使用冒号引出内容
        - 必须把标题视为内容上下文的一部分，并纳入总结理解
        - 不要机械重复标题或类型原文，但总结内容必须覆盖标题所限定的主题
        - 使用 2 到 4 个自然段
        - 每段 1 到 3 句
        - 语言保持客观、克制、压缩
        如果你想输出任何解释、标签或提示语，全部省略，直接输出总结正文。
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

    static func buildKeywordMessages(for snapshot: TopicSummarySnapshot) -> [DeepSeekMessage] {
        let notesBody = snapshot.noteContents
            .map { "- \($0.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")

        let systemPrompt = """
        你是一个关键词提取助手。
        根据用户提供的笔记标题和内容，提取 2 到 3 个关键词。
        要求：
        - 关键词必须是原文中出现过的词或短语，不能凭空创造
        - 优先选择出现频率较高、具有代表性的词或短语
        - 关键词长度 2 到 6 个字
        - 用中文逗号分隔
        - 只输出关键词本身，不要输出任何其他内容
        - 不要使用引号、编号或其他格式
        """

        let userPrompt = """
        标题：\(snapshot.title)

        内容：
        \(notesBody)
        """

        return [
            DeepSeekMessage(role: "system", content: systemPrompt),
            DeepSeekMessage(role: "user", content: userPrompt)
        ]
    }
}
