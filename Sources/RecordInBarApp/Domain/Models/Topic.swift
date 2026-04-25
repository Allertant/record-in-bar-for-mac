import Foundation
import SwiftData

enum AISummaryStatus: String, CaseIterable {
    case idle
    case processing
    case failed
}

@Model
final class Topic {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRawValue: String
    var aiSummaryStatusRawValue: String?
    var aiSummaryRequestedAt: Date?
    var aiSummaryErrorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "未命名",
        kind: TopicKind = .other,
        aiSummaryStatus: AISummaryStatus = .idle,
        aiSummaryRequestedAt: Date? = nil,
        aiSummaryErrorMessage: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kindRawValue = kind.rawValue
        self.aiSummaryStatusRawValue = aiSummaryStatus.rawValue
        self.aiSummaryRequestedAt = aiSummaryRequestedAt
        self.aiSummaryErrorMessage = aiSummaryErrorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: TopicKind {
        get { TopicKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    var aiSummaryStatus: AISummaryStatus {
        get { AISummaryStatus(rawValue: aiSummaryStatusRawValue ?? "") ?? .idle }
        set { aiSummaryStatusRawValue = newValue.rawValue }
    }

    var safeAISummaryErrorMessage: String {
        get { aiSummaryErrorMessage ?? "" }
        set { aiSummaryErrorMessage = newValue }
    }
}
