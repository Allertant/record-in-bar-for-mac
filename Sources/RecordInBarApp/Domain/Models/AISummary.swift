import Foundation
import SwiftData

@Model
final class AISummary {
    @Attribute(.unique) var id: UUID
    var topicID: UUID
    var model: String
    var thinkingEnabled: Bool
    var summaryText: String
    var keyPointsText: String
    var questionsText: String
    var nextIdeasText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        topicID: UUID,
        model: String,
        thinkingEnabled: Bool,
        summaryText: String,
        keyPointsText: String,
        questionsText: String,
        nextIdeasText: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.topicID = topicID
        self.model = model
        self.thinkingEnabled = thinkingEnabled
        self.summaryText = summaryText
        self.keyPointsText = keyPointsText
        self.questionsText = questionsText
        self.nextIdeasText = nextIdeasText
        self.createdAt = createdAt
    }
}
