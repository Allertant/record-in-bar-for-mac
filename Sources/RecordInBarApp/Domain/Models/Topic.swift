import Foundation
import SwiftData

@Model
final class Topic {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRawValue: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Untitled Topic",
        kind: TopicKind = .other,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kindRawValue = kind.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: TopicKind {
        get { TopicKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    var sortedNotes: [NoteItem] {
        []
    }

    var latestSummary: AISummary? {
        nil
    }
}
