import Foundation
import SwiftData

public enum AISummaryStatus: String, CaseIterable {
    case idle
    case processing
    case failed
}

@Model
public final class Topic {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var kindRawValue: String
    public var aiSummaryStatusRawValue: String?
    public var aiSummaryRequestedAt: Date?
    public var aiSummaryErrorMessage: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
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

    public var kind: TopicKind {
        get { TopicKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    public var aiSummaryStatus: AISummaryStatus {
        get { AISummaryStatus(rawValue: aiSummaryStatusRawValue ?? "") ?? .idle }
        set { aiSummaryStatusRawValue = newValue.rawValue }
    }

    public var safeAISummaryErrorMessage: String {
        get { aiSummaryErrorMessage ?? "" }
        set { aiSummaryErrorMessage = newValue }
    }
}
