import Foundation
import SwiftData

@Model
final class NoteItem {
    @Attribute(.unique) var id: UUID
    var topicID: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
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
