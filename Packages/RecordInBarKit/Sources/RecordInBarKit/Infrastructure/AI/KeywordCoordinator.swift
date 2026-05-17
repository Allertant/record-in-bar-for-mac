import Foundation
import SwiftData

enum KeywordCoordinator {
    private static let batchSize = 5
    private static let interval: TimeInterval = 30 * 60 // 30 minutes
    private static var timer: Timer?

    @MainActor
    static func startPeriodicCheck() {
        processPendingTopics()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                processPendingTopics()
            }
        }
    }

    static func stopPeriodicCheck() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    static func resetAllKeywordsIfNeeded() {
        let key = "RecordInBar.KeywordsDidResetV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let context = ModelContext(PersistenceController.shared.container)
        let topics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        for topic in topics {
            topic.keywords = []
            topic.keywordsGeneratedAt = nil
        }
        try? context.save()
    }

    @MainActor
    static func processPendingTopics() {
        let context = ModelContext(PersistenceController.shared.container)

        guard let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first,
              !settings.deepSeekAPIKey.isEmpty else {
            return
        }

        let topics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []
        let pending = topics.filter { topic in
            let hasContent = !topic.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard hasContent else { return false }
            guard let generatedAt = topic.keywordsGeneratedAt else { return true }
            return generatedAt < topic.updatedAt
        }

        let batch = Array(pending.prefix(batchSize))
        guard !batch.isEmpty else { return }

        let apiKey = settings.deepSeekAPIKey
        let model = settings.selectedModel

        Task.detached(priority: .utility) {
            for topic in batch {
                await generateKeywords(for: topic, apiKey: apiKey, model: model)
            }
        }
    }

    @MainActor
    private static func generateKeywords(for topic: Topic, apiKey: String, model: String) async {
        let context = ModelContext(PersistenceController.shared.container)

        guard let freshTopic = (try? context.fetch(FetchDescriptor<Topic>()))?.first(where: { $0.id == topic.id }) else { return }

        let notes = ((try? context.fetch(FetchDescriptor<NoteItem>())) ?? [])
            .filter { $0.topicID == topic.id }
            .map(\.content)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let title = freshTopic.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !notes.isEmpty else { return }

        let snapshot = TopicSummarySnapshot(
            topicID: freshTopic.id,
            title: title.isEmpty ? "未命名" : title,
            kindLabel: freshTopic.kind.label,
            noteContents: notes
        )

        let fullText = ([title] + notes).joined(separator: " ")

        do {
            let keywords = try await DeepSeekClient().generateKeywords(
                snapshot: snapshot,
                apiKey: apiKey,
                model: model
            )
            let validated = keywords.filter { keyword in
                fullText.contains(keyword)
            }
            guard !validated.isEmpty else { return }
            freshTopic.keywords = validated
            freshTopic.keywordsGeneratedAt = .now
            try? context.save()
        } catch {
            // Silently fail — will retry next cycle
        }
    }
}
