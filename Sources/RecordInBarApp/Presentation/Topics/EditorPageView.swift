import SwiftData
import SwiftUI

struct EditorPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AISummary.createdAt, order: .reverse) private var summaries: [AISummary]

    let topic: Topic?
    let note: NoteItem?
    let onBack: () -> Void
    let onDelete: () -> Void

    @State private var isReadMode = false
    @State private var isDeleteConfirmationVisible = false
    @State private var titleHeight: CGFloat = 44
    @State private var noteHeight: CGFloat = 260

    var body: some View {
        VStack(spacing: 0) {
            PanelPageHeader(title: "编辑记录") {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(IconHoverButtonStyle())
            } trailing: {
                HStack(spacing: 6) {
                    Button {
                        isReadMode.toggle()
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

            if let topic {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                RichTextFieldSection(
                                    title: "标题",
                                    text: titleBinding(for: topic),
                                    height: $titleHeight,
                                    minHeight: 38,
                                    font: .systemFont(ofSize: 13, weight: .semibold),
                                    isEditable: !isReadMode
                                )

                                if isReadMode {
                                    RichTextFieldSection(
                                        title: "笔记",
                                        text: noteBinding(for: topic),
                                        height: $noteHeight,
                                        minHeight: max(220, noteHeight),
                                        font: .systemFont(ofSize: 13),
                                        isEditable: false
                                    )
                                } else {
                                    RichTextFieldSection(
                                        title: "笔记",
                                        text: noteBinding(for: topic),
                                        height: $noteHeight,
                                        minHeight: 260,
                                        font: .systemFont(ofSize: 13),
                                        isEditable: true
                                    )
                                }
                            }
                        }

                        HStack {
                            if topic.aiSummaryStatus == .failed, !topic.safeAISummaryErrorMessage.isEmpty {
                                Text(topic.safeAISummaryErrorMessage)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                            } else if topic.aiSummaryStatus == .processing {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("AI 正在总结中，关闭面板后会继续保留状态。")
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
                            PanelCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI 总结")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)

                                    Text(latestSummary.summaryText)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                        .lineSpacing(4)
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
            } else {
                VStack {
                    Spacer(minLength: 0)
                    ContentUnavailableView(
                        "暂无记录",
                        systemImage: "square.and.pencil",
                        description: Text("请先创建一条新记录。")
                    )
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func titleBinding(for topic: Topic) -> Binding<String> {
        Binding(
            get: { topic.title },
            set: { newValue in
                topic.title = newValue
                topic.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private func noteBinding(for topic: Topic) -> Binding<String> {
        Binding(
            get: { note?.content ?? "" },
            set: { newValue in
                let targetNote: NoteItem
                if let note {
                    targetNote = note
                } else {
                    let created = NoteItem(topicID: topic.id, content: "")
                    modelContext.insert(created)
                    targetNote = created
                }

                targetNote.content = newValue
                targetNote.updatedAt = .now
                topic.updatedAt = .now
                try? modelContext.save()
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
}

private struct RichTextFieldSection: View {
    let title: String
    @Binding var text: String
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let font: NSFont
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            RichTextEditor(
                text: $text,
                dynamicHeight: $height,
                minHeight: minHeight,
                font: font,
                isEditable: isEditable
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
