import Foundation
import SwiftData

@Model
public final class NoteItem {
    @Attribute(.unique) public var id: UUID
    public var topicID: UUID
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        topicID: UUID,
        content: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.topicID = topicID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
