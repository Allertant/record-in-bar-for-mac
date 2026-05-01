import SwiftData
import SwiftUI

public struct AppMenuRootView: View {
    public init() {}
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.createdAt, order: .reverse) private var topics: [Topic]
    @Query private var notes: [NoteItem]
    @Query private var summaries: [AISummary]
    @Query private var settings: [AppSettings]

    @ObservedObject private var pinManager = PopoverPinManager.shared

    @State private var route: Route = .main
    @State private var selectedTopicID: UUID?
    @State private var searchText = ""
    @State private var pageReferenceDate = Date()
    @State private var cachedKeywords: [String] = []

    private enum Route {
        case main
        case editor
        case settings
    }

    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            Group {
                switch route {
                case .main:
                    mainPage
                        .transition(.opacity)
                case .editor:
                    EditorPageView(
                        topic: selectedTopic,
                        note: editableNote,
                        onPersistChange: { selectedTopicID = $0 },
                        onBack: { navigate(to: .main) },
                        onDelete: deleteSelectedTopic
                    )
                    .transition(.opacity)
                case .settings:
                    SettingsPageView(
                        settings: settings.first,
                        onBack: { navigate(to: .main) }
                    )
                    .environment(\.modelContext, modelContext)
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: route)
        }
        .task {
            SettingsBootstrap.ensureDefaultSettings(in: modelContext)
            refreshKeywords()
            await AISummaryCoordinator.resumePendingJobs()
            KeywordCoordinator.processPendingTopics()
        }
        .onChange(of: topics) { _, _ in
            refreshKeywords()
        }
        .onChange(of: route) { _, newValue in
            if newValue == .main {
                pageReferenceDate = .now
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(version)"
    }

    @MainActor
    private func navigate(to newRoute: Route) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            route = newRoute
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

    private func refreshKeywords() {
        let weighted = topics.flatMap { topic -> [(String, Double)] in
            let age = Date().timeIntervalSince(topic.updatedAt)
            let weight = 1.0 / (1.0 + age / 3600.0)
            return topic.keywords.map { ($0, weight) }
        }
        let grouped = Dictionary(grouping: weighted, by: \.0)
            .mapValues { $0.reduce(0) { $0 + $1.1 } }

        let newSet = Set(grouped.keys)
        let oldSet = Set(cachedKeywords)
        guard newSet != oldSet else { return }

        var result: [String] = []
        var remaining = grouped
        while !remaining.isEmpty {
            let total = remaining.values.reduce(0, +)
            var r = Double.random(in: 0..<max(total, 0.001))
            for (keyword, weight) in remaining {
                r -= weight
                if r <= 0 {
                    result.append(keyword)
                    remaining.removeValue(forKey: keyword)
                    break
                }
            }
        }
        cachedKeywords = result
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
            } middle: {
                EmptyView()
            } trailing: {
                Color.clear.frame(width: 1, height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        createTopicAndOpenEditor()
                    } label: {
                        PanelCard(padding: 10, tone: .create) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PanelCardTone.create.accent)

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

                    CompactSearchField(title: "搜索历史记录", keywords: cachedKeywords, text: $searchText)

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
                                relativeTimeText: HistoryTimeFormatter.string(for: topic.createdAt),
                                tone: historyTone(for: topic)
                            ) {
                                selectedTopicID = topic.id
                                navigate(to: .editor)
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

            HStack(spacing: 4) {
                Text(appVersion)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    pinManager.isPinned.toggle()
                } label: {
                    Image(systemName: pinManager.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(pinManager.isPinned ? .orange : .secondary)
                }
                .buttonStyle(IconHoverButtonStyle())
                .help(pinManager.isPinned ? "取消钉住" : "钉住面板")

                Button {
                    navigate(to: .settings)
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
        selectedTopicID = nil
        navigate(to: .editor)
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
        navigate(to: .main)
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

    private func historyTone(for topic: Topic) -> PanelCardTone {
        switch topic.kind {
        case .video:
            .historyBlue
        case .novel:
            .historyRose
        case .article:
            .historyOrange
        case .podcast:
            .historyGreen
        case .idea:
            .historySlate
        case .other:
            .historyBlue
        }
    }
}

private struct HistoryCardView: View {
    let topic: Topic
    let notePreview: String
    let query: String
    let relativeTimeText: String
    let tone: PanelCardTone
    let onTap: () -> Void

    public var body: some View {
        Button(action: onTap) {
            PanelCard(padding: 10, tone: tone) {
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
                        .foregroundStyle(tone.accent.opacity(0.82))
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
