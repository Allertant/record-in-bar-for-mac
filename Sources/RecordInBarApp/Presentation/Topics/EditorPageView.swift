import SwiftData
import SwiftUI

struct EditorPageView: View {
    @Environment(\.modelContext) private var modelContext

    let topic: Topic?
    let note: NoteItem?
    let onBack: () -> Void
    let onDelete: () -> Void

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
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.78))
                }
                .buttonStyle(IconHoverButtonStyle())
            }

            if let topic {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                CompactTextInput(title: "标题", text: titleBinding(for: topic))
                                CompactTextEditorInput(title: "笔记", text: noteBinding(for: topic), minHeight: 300)
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
}
