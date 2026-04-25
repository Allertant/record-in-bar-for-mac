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
            header

            if let topic {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("标题", text: titleBinding(for: topic))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 18, weight: .semibold))

                    TextEditor(text: noteBinding(for: topic))
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color.black.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Spacer(minLength: 0)
                }
                .padding(20)
            } else {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "square.and.pencil",
                    description: Text("请先创建一条新记录。")
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Label("返回", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(IconHoverButtonStyle())

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(IconHoverButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
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
