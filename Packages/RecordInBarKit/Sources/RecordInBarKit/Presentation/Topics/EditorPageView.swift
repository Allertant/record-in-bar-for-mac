import AppKit
import SwiftData
import SwiftUI

struct EditorPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTopics: [Topic]
    @Query(sort: \AISummary.createdAt, order: .reverse) private var summaries: [AISummary]
    @Query private var allNotes: [NoteItem]
    @Query private var allSummaries: [AISummary]

    @ObservedObject private var pinManager = PopoverPinManager.shared

    let topic: Topic?
    let note: NoteItem?
    let onPersistChange: (UUID?) -> Void
    let onBack: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationVisible = false
    @State private var titleHeight: CGFloat = 42
    @State private var noteHeight: CGFloat = 260
    @State private var draftTitle = ""
    @State private var draftNote = ""
    @State private var loadedTopicID: UUID?
    @State private var showCopiedToast = false
    @State private var showShareSheet = false
    @State private var isGeneratingImage = false
    @State private var showShareSuccess = false
    @State private var shareSuccessMessage = ""
    @State private var previewImage: NSImage?
    @State private var showImagePreview = false
    @State private var headerReferenceDate = Date()
    @State private var pendingPersistTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            PanelPageHeader(title: "编辑记录") {
                HStack(spacing: 6) {
                    Button {
                        flushDraftPersistence(existingTopicID: topic?.id)
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(IconHoverButtonStyle())

                    Button {
                        pinManager.isPinned.toggle()
                    } label: {
                        Image(systemName: pinManager.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(pinManager.isPinned ? .orange : .secondary)
                    }
                    .buttonStyle(IconHoverButtonStyle())
                }
            } middle: {
                if let topic = topic {
                    updateTimeHeader(for: topic)
                        .padding(.leading, 8)
                }
            } trailing: {
                HStack(spacing: 6) {
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
                    documentEditorContent

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
                                VStack(alignment: .leading, spacing: 10) {
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
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(PanelCardTone.summary.border.opacity(0.7), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
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
        .overlay {
            if showShareSuccess {
                Text(shareSuccessMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    .transition(.opacity)
            }
        }
        .overlay {
            if showImagePreview, let nsImage = previewImage {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeImagePreview()
                    }

                GeometryReader { geo in
                    let available = geo.size
                    let imgAspect = nsImage.size.width / nsImage.size.height
                    let displayWidth = min(available.width - 32, nsImage.size.width)
                    let displayHeight = displayWidth / imgAspect
                    let needsScroll = displayHeight > available.height - 32

                    if needsScroll {
                        ScrollView {
                            VStack(spacing: 12) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: displayWidth)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Button("关闭预览") { closeImagePreview() }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: displayWidth)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button("关闭预览") { closeImagePreview() }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .transition(.opacity)
            }
        }
        .task(id: topic?.id) {
            loadDraftIfNeeded()
        }
        .onDisappear {
            flushDraftPersistence(existingTopicID: topic?.id)
        }
    }

    private var documentEditorContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            RichTextFieldSection(
                text: titleBinding(for: topic),
                height: $titleHeight,
                minHeight: 42,
                maxHeight: nil,
                font: .systemFont(ofSize: 22, weight: .bold),
                isEditable: true,
                placeholder: "写下标题",
                verticalPadding: 2
            )
            .padding(.bottom, 10)

            Divider()
                .overlay(Color.black.opacity(0.06))

            RichTextFieldSection(
                text: noteBinding(for: topic),
                height: $noteHeight,
                minHeight: 300,
                maxHeight: nil,
                font: .systemFont(ofSize: 13),
                isEditable: true,
                placeholder: "记录你此刻的想法、线索或问题",
                verticalPadding: 8
            )
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private func titleBinding(for topic: Topic?) -> Binding<String> {
        Binding(
            get: { draftTitle },
            set: { newValue in
                draftTitle = newValue
                scheduleDraftPersistence(existingTopicID: topic?.id)
            }
        )
    }

    private func noteBinding(for topic: Topic?) -> Binding<String> {
        Binding(
            get: { draftNote },
            set: { newValue in
                draftNote = newValue
                scheduleDraftPersistence(existingTopicID: topic?.id)
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

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showShareSheet = false
        }
        showShareSuccessToast(message: "文字复制成功")
    }

    @MainActor
    private func generateAndShareImage() {
        guard !draftTitle.isEmpty || !draftNote.isEmpty else { return }
        isGeneratingImage = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let timeString = dateFormatter.string(from: Date())

        let card = ShareableNoteCard(title: draftTitle, note: draftNote, time: timeString)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))

            guard let nsImage = renderer.nsImage else {
                isGeneratingImage = false
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(nsImage.tiffRepresentation!, forType: .tiff)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showShareSheet = false
                isGeneratingImage = false
                previewImage = nsImage
                showImagePreview = true
            }
        }
    }

    @MainActor
    private func closeImagePreview() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showImagePreview = false
            previewImage = nil
        }
        showShareSuccessToast(message: "图片复制成功")
    }

    @MainActor
    private func showShareSuccessToast(message: String) {
        shareSuccessMessage = message
        withAnimation(.easeOut(duration: 0.18)) {
            showShareSuccess = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeIn(duration: 0.28)) {
                showShareSuccess = false
            }
        }
    }

    @MainActor
    private func loadDraftIfNeeded() {
        pendingPersistTask?.cancel()
        pendingPersistTask = nil
        let currentID = topic?.id
        guard loadedTopicID != currentID else { return }

        loadedTopicID = currentID
        draftTitle = topic?.title ?? ""
        draftNote = note?.content ?? ""
        isDeleteConfirmationVisible = false
    }

    @MainActor
    private func scheduleDraftPersistence(existingTopicID: UUID?) {
        pendingPersistTask?.cancel()
        pendingPersistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistDraft(existingTopicID: existingTopicID)
            pendingPersistTask = nil
        }
    }

    @MainActor
    private func flushDraftPersistence(existingTopicID: UUID?) {
        pendingPersistTask?.cancel()
        pendingPersistTask = nil
        persistDraft(existingTopicID: existingTopicID)
    }

    @MainActor
    private func persistDraft(existingTopicID: UUID?) {
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
    @Binding var text: String
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let font: NSFont
    let isEditable: Bool
    let placeholder: String
    var verticalPadding: CGFloat

    init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        minHeight: CGFloat,
        maxHeight: CGFloat? = nil,
        font: NSFont,
        isEditable: Bool,
        placeholder: String,
        verticalPadding: CGFloat = 6
    ) {
        self._text = text
        self._height = height
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.font = font
        self.isEditable = isEditable
        self.placeholder = placeholder
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.init(font))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, verticalPadding + 6)
                    .allowsHitTesting(false)
            }

            RichTextEditor(
                text: $text,
                dynamicHeight: $height,
                minHeight: minHeight,
                maxHeight: maxHeight,
                font: font,
                isEditable: isEditable,
                verticalPadding: verticalPadding
            )
            .frame(height: max(minHeight, height))
        }
    }
}

private struct ShareableNoteCard: View {
    let title: String
    let note: String
    let time: String

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

            HStack {
                Spacer()
                Text(time)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
        }
        .padding(28)
        .frame(width: 400, alignment: .topLeading)
        .background(Color.white)
    }
}
