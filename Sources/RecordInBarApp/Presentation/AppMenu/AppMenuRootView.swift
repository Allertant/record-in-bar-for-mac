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
    @State private var pageReferenceDate = Date()

    private enum Route {
        case main
        case editor
        case settings
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
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
            await AISummaryCoordinator.resumePendingJobs()
        }
        .onChange(of: route) { _, newValue in
            if newValue == .main {
                pageReferenceDate = .now
            }
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
            PanelPageHeader(title: "状态栏记录") {
                Color.clear.frame(width: 1, height: 1)
            } trailing: {
                Text("\(topics.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        createTopicAndOpenEditor()
                    } label: {
                        PanelCard(padding: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("新建记录")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("输入标题和笔记，内容实时保存。")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    CompactSearchField(title: "搜索历史记录", text: $searchText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("历史记录")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        LazyVStack(spacing: 8) {
                        ForEach(filteredTopics) { topic in
                            HistoryCardView(
                                topic: topic,
                                notePreview: previewText(for: topic),
                                query: searchText,
                                relativeTimeText: RelativeTimeFormatter.string(for: topic.updatedAt, reference: pageReferenceDate)
                            ) {
                                selectedTopicID = topic.id
                                route = .editor
                            }
                        }

                        if filteredTopics.isEmpty {
                            ContentUnavailableView(
                                "暂无历史记录",
                                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                description: Text("请先创建记录，或调整搜索关键词。")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        }
                    }
                    }
                }
                .padding(12)
                .background(
                    Color(nsColor: .windowBackgroundColor)
                        .contentShape(Rectangle())
                        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
                )
            }
            .scrollIndicators(.hidden)

            Divider()

            HStack {
                Spacer()

                Button {
                    route = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(IconHoverButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
            .searchPreview(for: searchText)
            .nilIfEmpty ?? "暂无笔记"
    }
}

private struct HistoryCardView: View {
    let topic: Topic
    let notePreview: String
    let query: String
    let relativeTimeText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            PanelCard(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    HighlightedText(
                        topic.title.nilIfEmpty ?? "未命名",
                        query: query,
                        font: .system(size: 13, weight: .semibold),
                        foregroundStyle: .primary
                    )
                    .lineLimit(2)

                    Spacer()

                    Text(relativeTimeText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HighlightedText(
                    notePreview,
                    query: query,
                    font: .system(size: 12),
                    foregroundStyle: .secondary
                )
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }

    func searchPreview(for query: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return trimmed }

        let lowerText = trimmed.lowercased()
        let lowerNeedle = needle.lowercased()
        guard let range = lowerText.range(of: lowerNeedle) else { return trimmed }

        let startOffset = max(0, lowerText.distance(from: lowerText.startIndex, to: range.lowerBound) - 22)
        let endOffset = min(lowerText.count, lowerText.distance(from: lowerText.startIndex, to: range.upperBound) + 38)
        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: startOffset)
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: endOffset)
        let snippet = String(trimmed[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = startOffset > 0 ? "…" : ""
        let suffix = endOffset < trimmed.count ? "…" : ""
        return prefix + snippet + suffix
    }
}
