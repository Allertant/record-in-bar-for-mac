import Foundation
import SwiftData

actor AISummaryTaskRegistry {
    private var runningTopicIDs: Set<UUID> = []

    func start(_ topicID: UUID) -> Bool {
        runningTopicIDs.insert(topicID).inserted
    }

    func finish(_ topicID: UUID) {
        runningTopicIDs.remove(topicID)
    }
}

enum AISummaryCoordinator {
    private static let registry = AISummaryTaskRegistry()

    static func enqueue(topicID: UUID) {
        Task.detached(priority: .userInitiated) {
            guard await registry.start(topicID) else { return }
            defer { Task { await registry.finish(topicID) } }

            do {
                let payload = try await MainActor.run { try loadPayload(topicID: topicID) }
                let result = try await DeepSeekClient().generateSummary(
                    snapshot: payload.snapshot,
                    apiKey: payload.apiKey,
                    model: payload.model,
                    thinkingEnabled: payload.thinkingEnabled,
                    reasoningEffort: payload.reasoningEffort
                )
                try await MainActor.run {
                    try saveSuccess(topicID: topicID, result: result, model: payload.model, thinkingEnabled: payload.thinkingEnabled)
                }
            } catch {
                await MainActor.run {
                    saveFailure(topicID: topicID, message: error.localizedDescription)
                }
            }
        }
    }

    static func resumePendingJobs() async {
        let processingTopicIDs = await MainActor.run { pendingTopicIDs() }
        for topicID in processingTopicIDs {
            enqueue(topicID: topicID)
        }
    }

    @MainActor
    private static func pendingTopicIDs() -> [UUID] {
        let context = ModelContext(PersistenceController.shared.container)
        let topics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        return topics.filter { $0.aiSummaryStatus == .processing }.map(\.id)
    }

    @MainActor
    private static func loadPayload(topicID: UUID) throws -> SummaryPayload {
        let context = ModelContext(PersistenceController.shared.container)
        let topic = try fetchTopic(topicID: topicID, context: context)
        let settings = try fetchSettings(context: context)
        let notes = try fetchNotes(topicID: topicID, context: context)
            .map(\.content)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let snapshot = TopicSummarySnapshot(
            topicID: topicID,
            title: topic.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名" : topic.title,
            kindLabel: topic.kind.label,
            noteContents: notes
        )

        return SummaryPayload(
            snapshot: snapshot,
            apiKey: settings.deepSeekAPIKey,
            model: settings.selectedModel,
            thinkingEnabled: settings.thinkingEnabled,
            reasoningEffort: settings.reasoningEffort
        )
    }

    @MainActor
    private static func saveSuccess(topicID: UUID, result: DeepSeekSummaryResult, model: String, thinkingEnabled: Bool) throws {
        let context = ModelContext(PersistenceController.shared.container)
        let topic = try fetchTopic(topicID: topicID, context: context)

        let existingSummaries = try fetchSummaries(topicID: topicID, context: context)
        existingSummaries.forEach(context.delete)

        context.insert(
            AISummary(
                topicID: topicID,
                model: model,
                thinkingEnabled: thinkingEnabled,
                summaryText: result.summaryText
            )
        )

        topic.aiSummaryStatus = .idle
        topic.safeAISummaryErrorMessage = ""
        topic.updatedAt = .now
        try context.save()
    }

    @MainActor
    private static func saveFailure(topicID: UUID, message: String) {
        let context = ModelContext(PersistenceController.shared.container)
        guard let topic = try? fetchTopic(topicID: topicID, context: context) else { return }
        topic.aiSummaryStatus = .failed
        topic.safeAISummaryErrorMessage = message
        topic.updatedAt = .now
        try? context.save()
    }

    @MainActor
    private static func fetchTopic(topicID: UUID, context: ModelContext) throws -> Topic {
        let descriptor = FetchDescriptor<Topic>()
        guard let topic = try context.fetch(descriptor).first(where: { $0.id == topicID }) else {
            throw DeepSeekClientError.invalidResponse
        }
        return topic
    }

    @MainActor
    private static func fetchNotes(topicID: UUID, context: ModelContext) throws -> [NoteItem] {
        try context.fetch(FetchDescriptor<NoteItem>())
            .filter { $0.topicID == topicID }
            .sorted(using: KeyPathComparator(\.updatedAt, order: .forward))
    }

    @MainActor
    private static func fetchSummaries(topicID: UUID, context: ModelContext) throws -> [AISummary] {
        try context.fetch(FetchDescriptor<AISummary>())
            .filter { $0.topicID == topicID }
    }

    @MainActor
    private static func fetchSettings(context: ModelContext) throws -> AppSettings {
        guard let settings = try context.fetch(FetchDescriptor<AppSettings>()).first else {
            throw DeepSeekClientError.missingAPIKey
        }
        return settings
    }
}

private struct SummaryPayload: Sendable {
    let snapshot: TopicSummarySnapshot
    let apiKey: String
    let model: String
    let thinkingEnabled: Bool
    let reasoningEffort: String
}
