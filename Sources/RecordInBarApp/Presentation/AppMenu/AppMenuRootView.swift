import SwiftData
import SwiftUI

struct AppMenuRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.updatedAt, order: .reverse) private var topics: [Topic]
    @Query private var notes: [NoteItem]
    @Query private var summaries: [AISummary]
    @Query private var settings: [AppSettings]

    @State private var route: Route = .main
    @State private var selectedTopicID: UUID?
    @State private var searchText = ""

    private enum Route {
        case main
        case editor
        case settings
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch route {
            case .main:
                mainPage
            case .editor:
                EditorPageView(
                    topic: selectedTopic,
                    note: editableNote,
                    onBack: { route = .main },
                    onDelete: deleteSelectedTopic
                )
            case .settings:
                SettingsPageView(
                    settings: settings.first,
                    onBack: { route = .main }
                )
                .environment(\.modelContext, modelContext)
            }
        }
        .task {
            SettingsBootstrap.ensureDefaultSettings(in: modelContext)
        }
    }

    private var selectedTopic: Topic? {
        guard let selectedTopicID else { return nil }
        return topics.first(where: { $0.id == selectedTopicID })
    }

    private var editableNote: NoteItem? {
        guard let selectedTopic else { return nil }
        return notes
            .filter { $0.topicID == selectedTopic.id }
            .sorted(using: KeyPathComparator(\.updatedAt, order: .reverse))
            .first
    }

    private var filteredTopics: [Topic] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return topics }

        return topics.filter { topic in
            topic.title.localizedCaseInsensitiveContains(trimmed) ||
            notes.contains(where: { $0.topicID == topic.id && $0.content.localizedCaseInsensitiveContains(trimmed) })
        }
    }

    private var mainPage: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Record in Bar")
                    .font(.system(size: 22, weight: .semibold))

                Button {
                    createTopicAndOpenEditor()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("New", systemImage: "square.and.pencil")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }

                        Text("Create a new title and start typing notes immediately.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                TextField("Search history", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTopics) { topic in
                            HistoryCardView(
                                topic: topic,
                                notePreview: previewText(for: topic)
                            ) {
                                selectedTopicID = topic.id
                                route = .editor
                            }
                        }

                        if filteredTopics.isEmpty {
                            ContentUnavailableView(
                                "No History",
                                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                description: Text("Create a record or adjust your search.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(20)

            Divider()

            HStack {
                Spacer()

                Button {
                    route = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(IconHoverButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    @MainActor
    private func createTopicAndOpenEditor() {
        let topic = Topic(title: "", kind: .other)
        modelContext.insert(topic)
        let note = NoteItem(topicID: topic.id, content: "")
        modelContext.insert(note)
        selectedTopicID = topic.id
        try? modelContext.save()
        route = .editor
    }

    @MainActor
    private func deleteSelectedTopic() {
        guard let selectedTopic else { return }

        notes
            .filter { $0.topicID == selectedTopic.id }
            .forEach(modelContext.delete)

        summaries
            .filter { $0.topicID == selectedTopic.id }
            .forEach(modelContext.delete)

        selectedTopicID = nil
        modelContext.delete(selectedTopic)
        try? modelContext.save()
        route = .main
    }

    private func previewText(for topic: Topic) -> String {
        notes
            .filter { $0.topicID == topic.id }
            .sorted(using: KeyPathComparator(\.updatedAt, order: .reverse))
            .first?
            .content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "No notes yet."
    }
}

private struct HistoryCardView: View {
    let topic: Topic
    let notePreview: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(topic.title.nilIfEmpty ?? "Untitled")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(topic.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(notePreview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
