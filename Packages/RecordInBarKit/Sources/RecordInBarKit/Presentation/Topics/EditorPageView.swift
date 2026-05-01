import AppKit
import SwiftData
import SwiftUI

struct EditorPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTopics: [Topic]
    @Query(sort: \AISummary.createdAt, order: .reverse) private var summaries: [AISummary]
    @Query private var allNotes: [NoteItem]
    @Query private var allSummaries: [AISummary]

    let topic: Topic?
    let note: NoteItem?
    let onPersistChange: (UUID?) -> Void
    let onBack: () -> Void
    let onDelete: () -> Void

    @State private var isReadMode = false
    @State private var isDeleteConfirmationVisible = false
    @State private var titleHeight: CGFloat = 22
    @State private var noteHeight: CGFloat = 260
    @State private var draftTitle = ""
    @State private var draftNote = ""
    @State private var loadedTopicID: UUID?
    @State private var showCopiedToast = false
    @State private var showShareSheet = false
    @State private var isGeneratingImage = false
    @State private var headerReferenceDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            PanelPageHeader(title: "编辑记录") {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(IconHoverButtonStyle())
            } middle: {
                if let topic = topic, !isReadMode {
                    updateTimeHeader(for: topic)
                        .padding(.leading, 8)
                }
            } trailing: {
                HStack(spacing: 6) {
                    if isReadMode {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showShareSheet = true
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(IconHoverButtonStyle())
                    }

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isReadMode.toggle()
                            headerReferenceDate = .now
                        }
                    } label: {
                        Image(systemName: isReadMode ? "square.and.pencil" : "book")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(IconHoverButtonStyle())

                    if isDeleteConfirmationVisible {
                        Button("取消") {
                            isDeleteConfirmationVisible = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                        Button("删除") {
                            onDelete()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                    } else {
                        Button {
                            isDeleteConfirmationVisible = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.78))
                        }
                        .buttonStyle(IconHoverButtonStyle())
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Main Content Container (Title + Note)
                    VStack(alignment: .leading, spacing: 12) {
                        if isReadMode {
                            readModeContent
                                .transition(.opacity)
                        } else {
                            editModeContent
                                .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isReadMode)
                    .layoutPriority(1)

                    // AI Summary Section
                    if let topic {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                if topic.aiSummaryStatus == .failed, !topic.safeAISummaryErrorMessage.isEmpty {
                                    Text(topic.safeAISummaryErrorMessage)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red)
                                } else if topic.aiSummaryStatus == .processing {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("AI 正在总结中...")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    requestAISummary(for: topic)
                                } label: {
                                    HStack(spacing: 6) {
                                        if topic.aiSummaryStatus == .processing {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text(topic.aiSummaryStatus == .processing ? "总结中" : "AI 分析")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                }
                                .buttonStyle(PrimaryHoverButtonStyle())
                                .disabled(topic.aiSummaryStatus == .processing)
                            }

                            if let latestSummary = latestSummary(for: topic) {
                                PanelCard(tone: .summary) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("AI 总结")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(PanelCardTone.summary.accent)

                                        Text(latestSummary.summaryText)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary)
                                            .textSelection(.enabled)
                                            .lineSpacing(4)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        HStack {
                                            Spacer()

                                            ZStack(alignment: .bottomTrailing) {
                                                if showCopiedToast {
                                                    CopyToastView(text: "已复制")
                                                        .offset(y: -24)
                                                        .transition(.move(edge: .top).combined(with: .opacity))
                                                }

                                                Button {
                                                    copySummary(latestSummary.summaryText)
                                                } label: {
                                                    Image(systemName: "doc.on.doc")
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(PanelCardTone.summary.accent)
                                                }
                                                .buttonStyle(IconHoverButtonStyle())
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .scrollIndicators(.hidden)
            .background(
                Color(nsColor: .windowBackgroundColor)
                    .contentShape(Rectangle())
                    .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
            )
        }
        .overlay {
            if showShareSheet {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showShareSheet = false
                        }
                    }

                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        Button {
                            shareText()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showShareSheet = false
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 20)

                                Text("分享文字")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.horizontal, 14)

                        Button {
                            generateAndShareImage()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "photo")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 20)

                                if isGeneratingImage {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("生成中...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("分享图片")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingImage)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task(id: topic?.id) {
            loadDraftIfNeeded()
        }
    }

    private var editModeContent: some View {
        PanelCard(tone: .editor) {
            VStack(alignment: .leading, spacing: 10) {
                RichTextFieldSection(
                    title: "标题",
                    text: titleBinding(for: topic),
                    height: $titleHeight,
                    minHeight: 22,
                    font: .systemFont(ofSize: 13, weight: .semibold),
                    isEditable: true,
                    verticalPadding: 4
                )

                ZStack(alignment: .topTrailing) {
                    RichTextFieldSection(
                        title: "笔记",
                        text: noteBinding(for: topic),
                        height: $noteHeight,
                        minHeight: 260,
                        font: .systemFont(ofSize: 13),
                        isEditable: true,
                        onCopy: { copySummary(draftNote) }
                    )

                    if showCopiedToast {
                        CopyToastView(text: "已复制")
                            .padding(.top, -4)
                            .padding(.trailing, 28)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var readModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(draftTitle.isEmpty ? "无标题" : draftTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let topic = topic {
                    Text("更新于 \(RelativeTimeFormatter.string(for: topic.updatedAt, reference: .now))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 4)

            Divider()
                .opacity(0.6)

            VStack(alignment: .leading, spacing: 8) {
                if draftNote.isEmpty {
                    Text("暂无笔记内容")
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(.tertiary)
                } else {
                    Text(draftNote)
                        .font(.system(size: 13))
                        .lineSpacing(6)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(minHeight: 280, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.03), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    copySummary(draftNote)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(IconHoverButtonStyle())
                .padding(8)
                .overlay(alignment: .top) {
                    if showCopiedToast {
                        CopyToastView(text: "已复制")
                            .fixedSize()
                            .offset(y: -6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private func titleBinding(for topic: Topic?) -> Binding<String> {
        Binding(
            get: { draftTitle },
            set: { newValue in
                draftTitle = newValue
                persistDraft(existingTopic: topic)
            }
        )
    }

    private func noteBinding(for topic: Topic?) -> Binding<String> {
        Binding(
            get: { draftNote },
            set: { newValue in
                draftNote = newValue
                persistDraft(existingTopic: topic)
            }
        )
    }

    @MainActor
    private func requestAISummary(for topic: Topic) {
        topic.aiSummaryStatus = .processing
        topic.aiSummaryRequestedAt = .now
        topic.safeAISummaryErrorMessage = ""
        topic.updatedAt = .now
        try? modelContext.save()
        AISummaryCoordinator.enqueue(topicID: topic.id)
    }

    private func latestSummary(for topic: Topic) -> AISummary? {
        summaries.first(where: { $0.topicID == topic.id })
    }

    @MainActor
    private func copySummary(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        withAnimation(.easeOut(duration: 0.18)) {
            showCopiedToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeIn(duration: 0.28)) {
                showCopiedToast = false
            }
        }
    }

    @MainActor
    private func shareText() {
        var text = ""
        if !draftTitle.isEmpty {
            text += draftTitle
        }
        if !draftNote.isEmpty {
            if !text.isEmpty { text += "\n\n" }
            text += draftNote
        }
        guard !text.isEmpty else { return }

        let picker = NSSharingServicePicker(items: [text])
        guard let contentView = NSApp.keyWindow?.contentView else { return }
        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)

        showShareSuccessToast()
    }

    @MainActor
    private func generateAndShareImage() {
        guard !draftTitle.isEmpty || !draftNote.isEmpty else { return }
        isGeneratingImage = true

        let card = ShareableNoteCard(title: draftTitle, note: draftNote)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0

        Task { @MainActor in
            // Defer slightly so the loading indicator renders first
            try? await Task.sleep(for: .milliseconds(100))

            guard let nsImage = renderer.nsImage else {
                isGeneratingImage = false
                return
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showShareSheet = false
                isGeneratingImage = false
            }

            let picker = NSSharingServicePicker(items: [nsImage])
            guard let contentView = NSApp.keyWindow?.contentView else { return }
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)

            showShareSuccessToast()
        }
    }

    @MainActor
    private func showShareSuccessToast() {
        withAnimation(.easeOut(duration: 0.18)) {
            showCopiedToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeIn(duration: 0.28)) {
                showCopiedToast = false
            }
        }
    }

    @MainActor
    private func loadDraftIfNeeded() {
        let currentID = topic?.id
        guard loadedTopicID != currentID else { return }

        loadedTopicID = currentID
        draftTitle = topic?.title ?? ""
        draftNote = note?.content ?? ""
        isDeleteConfirmationVisible = false
    }

    @MainActor
    private func persistDraft(existingTopic: Topic?) {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)

        guard existingTopic != nil || loadedTopicID != nil || !trimmedTitle.isEmpty || !trimmedNote.isEmpty else {
            return
        }

        let targetTopic: Topic
        if let existingTopic {
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

            allSummaries
                .filter { $0.topicID == targetTopic.id }
                .forEach(modelContext.delete)

            modelContext.delete(targetTopic)
            loadedTopicID = nil
            onPersistChange(nil)
        }

        try? modelContext.save()
    }

    private func updateTimeHeader(for topic: Topic) -> some View {
        Text(RelativeTimeFormatter.string(for: topic.updatedAt, reference: headerReferenceDate))
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.leading, -4)
    }
}

private struct CopyToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.78))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

private struct RichTextFieldSection: View {
    let title: String
    @Binding var text: String
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let font: NSFont
    let isEditable: Bool
    var onCopy: (() -> Void)? = nil
    var verticalPadding: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if let onCopy {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .buttonStyle(IconHoverButtonStyle())
                }
            }

            RichTextEditor(
                text: $text,
                dynamicHeight: $height,
                minHeight: minHeight,
                font: font,
                isEditable: isEditable,
                verticalPadding: verticalPadding
            )
            .frame(height: max(minHeight, height))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct ShareableNoteCard: View {
    let title: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.isEmpty ? "无标题" : title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            if !note.isEmpty {
                Text(note)
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
            }
        }
        .padding(28)
        .frame(width: 400, alignment: .topLeading)
        .background(Color.white)
    }
}
