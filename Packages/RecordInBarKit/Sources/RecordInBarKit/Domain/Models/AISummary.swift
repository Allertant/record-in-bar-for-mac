import Foundation
import SwiftData

@Model
public final class AISummary {
    @Attribute(.unique) public var id: UUID
    public var topicID: UUID
    public var model: String
    public var thinkingEnabled: Bool
    public var summaryText: String
    public var createdAt: Date

    public init(
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
