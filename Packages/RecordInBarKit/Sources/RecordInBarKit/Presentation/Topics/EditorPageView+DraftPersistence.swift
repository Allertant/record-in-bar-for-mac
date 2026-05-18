import SwiftData
import SwiftUI

extension EditorPageView {
    @MainActor
    func loadDraftIfNeeded() {
        pendingPersistTask?.cancel()
        pendingPersistTask = nil
        let currentID = topic?.id
        guard loadedTopicID != currentID else { return }

        loadedTopicID = currentID
        draftTitle = topic?.title ?? ""
        draftNote = note?.content ?? ""
        showDeleteConfirmation = false
    }

    @MainActor
    func scheduleDraftPersistence(existingTopicID: UUID?) {
        pendingPersistTask?.cancel()
        pendingPersistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistDraft(existingTopicID: existingTopicID)
            pendingPersistTask = nil
        }
    }

    @MainActor
    func flushDraftPersistence(existingTopicID: UUID?) {
        pendingPersistTask?.cancel()
        pendingPersistTask = nil
        persistDraft(existingTopicID: existingTopicID)
    }

    @MainActor
    func persistDraft(existingTopicID: UUID?) {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)

        guard existingTopicID != nil || loadedTopicID != nil || !trimmedTitle.isEmpty || !trimmedNote.isEmpty else {
            return
        }

        let targetTopic: Topic
        if let existingTopicID, let existingTopic = allTopics.first(where: { $0.id == existingTopicID }) {
            targetTopic = existingTopic
        } else if let loadedTopicID {
            guard let storedTopic = allTopics.first(where: { $0.id == loadedTopicID }) else {
                return
            }
            targetTopic = storedTopic
        } else {
            let createdTopic = Topic(title: trimmedTitle, kind: .other)
            modelContext.insert(createdTopic)
            targetTopic = createdTopic
            loadedTopicID = createdTopic.id
            onPersistChange(createdTopic.id)
        }

        targetTopic.title = draftTitle
        targetTopic.updatedAt = .now

        let existingNotes = allNotes
            .filter { $0.topicID == targetTopic.id }
            .sorted(using: KeyPathComparator(\.updatedAt, order: .reverse))

        if let firstNote = existingNotes.first {
            if trimmedNote.isEmpty {
                modelContext.delete(firstNote)
            } else {
                firstNote.content = draftNote
                firstNote.updatedAt = .now
            }
        } else if !trimmedNote.isEmpty {
            let createdNote = NoteItem(topicID: targetTopic.id, content: draftNote)
            modelContext.insert(createdNote)
        }

        if trimmedTitle.isEmpty && trimmedNote.isEmpty {
            allNotes
                .filter { $0.topicID == targetTopic.id }
                .forEach(modelContext.delete)

            let targetID = targetTopic.id
            let descriptor = FetchDescriptor<NoteImage>(predicate: #Predicate<NoteImage> { $0.topicID == targetID })
            let topicImages = (try? modelContext.fetch(descriptor)) ?? []
            topicImages.forEach { ImageStorage.deleteImage(relativePath: $0.relativePath) }
            topicImages.forEach(modelContext.delete)

            allSummaries
                .filter { $0.topicID == targetTopic.id }
                .forEach(modelContext.delete)

            modelContext.delete(targetTopic)
            loadedTopicID = nil
            onPersistChange(nil)
        }

        try? modelContext.save()
    }
}
