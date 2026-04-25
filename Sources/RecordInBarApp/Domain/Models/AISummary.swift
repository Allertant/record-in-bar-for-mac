import Foundation
import SwiftData

@Model
final class AISummary {
    @Attribute(.unique) var id: UUID
    var topicID: UUID
    var model: String
    var thinkingEnabled: Bool
    var summaryText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        topicID: UUID,
        model: String,
        thinkingEnabled: Bool,
        summaryText: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.topicID = topicID
        self.model = model
        self.thinkingEnabled = thinkingEnabled
        self.summaryText = summaryText
        self.createdAt = createdAt
    }
}
