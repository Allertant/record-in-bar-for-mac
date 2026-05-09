import AppKit
import SwiftData
import SwiftUI

struct EditorPageView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Query var allTopics: [Topic]
    @Query(sort: \AISummary.createdAt, order: .reverse) var summaries: [AISummary]
    @Query var allNotes: [NoteItem]
    @Query var allSummaries: [AISummary]
    @Query(sort: \NoteImage.createdAt) var noteImages: [NoteImage]
    @Query var appSettings: [AppSettings]

    @ObservedObject private var pinManager = PopoverPinManager.shared

    let topic: Topic?
    let note: NoteItem?
    let onPersistChange: (UUID?) -> Void
    let onBack: () -> Void
    let onDelete: () -> Void

    @State var showDeleteConfirmation = false
    @State var draftTitle = ""
    @State var draftNote = ""
    @State var loadedTopicID: UUID?
    @State private var showCopiedToast = false
    @State var showShareSheet = false
    @State var isGeneratingImage = false
    @State var showShareSuccess = false
    @State var shareSuccessMessage = ""
    @State var previewImage: NSImage?
    @State var showImagePreview = false
    @State private var headerReferenceDate = Date()
    @State var imagePreviewPanel: NSPanel?
    @State var imagePreviewParentWindowNumber: Int?
    @State var currentPreviewImageID: UUID?
    @State var imagePreviewState = ImagePreviewState()
    @State var imagePreviewTask: Task<Void, Never>?
    @State var pendingPersistTask: Task<Void, Never>?
    @State private var editorScrollOffsetY: CGFloat = 0
    @State private var pendingEditorRestoreOffsetY: CGFloat?

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

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.78))
                    }
                    .buttonStyle(IconHoverButtonStyle())
                }
            }

            ObservableVerticalScrollView(
                contentOffsetY: $editorScrollOffsetY,
                restoreOffsetY: $pendingEditorRestoreOffsetY
            ) {
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
                                            .foregroundStyle(PanelCardTone.summary.accent(for: colorScheme))

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
                                                        .foregroundStyle(PanelCardTone.summary.accent(for: colorScheme))
                                                }
                                                .buttonStyle(IconHoverButtonStyle())
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .background(colorScheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.16) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(PanelCardTone.summary.border(for: colorScheme).opacity(0.7), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(
                Color(nsColor: .windowBackgroundColor)
                    .contentShape(Rectangle())
                    .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
            )
        }
        .task(id: topic?.id) {
            loadDraftIfNeeded()
        }
        .onDisappear {
            imagePreviewTask?.cancel()
            imagePreviewTask = nil
            closeImagePreviewPanel()
            flushDraftPersistence(existingTopicID: topic?.id)
        }
        .overlay { modalOverlay }
        .overlay { toastOverlay }
        .onReceive(NotificationCenter.default.publisher(for: .escKeyPressed)) { _ in
            flushDraftPersistence(existingTopicID: topic?.id)
            onBack()
        }
    }

    // MARK: - Single always-present modal overlay

    private var hasActiveModal: Bool {
        showShareSheet || showDeleteConfirmation || showImagePreview
    }

    @ViewBuilder
    private var modalOverlay: some View {
        ZStack {
            Button { dismissAllModals() } label: {
                Color.black.opacity(hasActiveModal ? 0.25 : 0)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)

            shareSheetPanel
                .opacity(showShareSheet ? 1 : 0)

            ConfirmActionPage(
                icon: "trash",
                iconTint: .red,
                title: deleteConfirmTitle,
                message: "删除后无法恢复，确认删除？",
                confirmLabel: "确认删除",
                onCancel: { showDeleteConfirmation = false },
                onConfirm: {
                    showDeleteConfirmation = false
                    onDelete()
                }
            )
            .background(.regularMaterial)
            .opacity(showDeleteConfirmation ? 1 : 0)

            shareImagePreviewPanel
                .opacity(showImagePreview ? 1 : 0)
        }
        .allowsHitTesting(hasActiveModal)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: hasActiveModal)
    }

    private func dismissAllModals() {
        showShareSheet = false
        showDeleteConfirmation = false
        showImagePreview = false
        previewImage = nil
    }

    @ViewBuilder
    private var shareImagePreviewPanel: some View {
        if let nsImage = previewImage {
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

                            Button("关闭预览") { closeShareImagePreview() }
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

                        Button("关闭预览") { closeShareImagePreview() }
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
        }
    }

    @ViewBuilder
    private var shareSheetPanel: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                Button {
                    shareText()
                    showShareSheet = false
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
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
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

    private var deleteConfirmTitle: String {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名记录" : trimmed
    }

    private var documentEditorContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("写下标题", text: titleBinding(for: topic), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1 ... 3)
                .foregroundStyle(.primary)
                .padding(.bottom, 10)

            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))

            ZStack(alignment: .topLeading) {
                RichTextEditor(
                    text: noteBinding(for: topic),
                    minHeight: 100,
                    font: .systemFont(ofSize: 13),
                    isEditable: true,
                    verticalPadding: 8,
                    onImagePasted: { image in
                        savePastedImage(image)
                    },
                    imageLoader: { uuid in
                        guard let ni = noteImages.first(where: { $0.id == uuid }) else { return nil }
                        return ImageStorage.loadImage(relativePath: ni.relativePath)
                    },
                    onImageDeleted: { uuid in
                        deleteInlineImage(uuid)
                    },
                    onImageClicked: { uuid in
                        openImagePreview(uuid: uuid)
                    }
                )

                if draftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("记录你此刻的想法、线索或问题")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 2)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 10)

            HStack {
                Spacer()

                Text(noteStatsText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(colorScheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.16) : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
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

    private var visibleNoteText: String {
        draftNote.replacingOccurrences(
            of: #"\[IMG:[0-9A-Fa-f\-]+\]"#,
            with: "",
            options: .regularExpression
        )
    }

    private var noteCharacterCount: Int {
        visibleNoteText.filter { !$0.isNewline }.count
    }

    private var noteImageCount: Int {
        let pattern = #"\[IMG:[0-9A-Fa-f\-]+\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(draftNote.startIndex..., in: draftNote)
        return regex.numberOfMatches(in: draftNote, range: range)
    }

    private var noteStatsText: String {
        if noteImageCount > 0 {
            return "\(noteCharacterCount) 字 · \(noteImageCount) 图"
        }
        return "\(noteCharacterCount) 字"
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

    func latestSummary(for topic: Topic) -> AISummary? {
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

    private func updateTimeHeader(for topic: Topic) -> some View {
        Text(RelativeTimeFormatter.string(for: topic.updatedAt, reference: headerReferenceDate))
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.leading, -4)
    }
}
