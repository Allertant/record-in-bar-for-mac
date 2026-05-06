import AppKit
import SwiftUI

struct CopyToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.78))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

enum ShareableNoteSegment {
    case text(String)
    case image(NSImage)
}

struct ShareableNoteCard: View {
    let title: String
    let noteSegments: [ShareableNoteSegment]
    let time: String
    let summary: String?
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.isEmpty ? "无标题" : title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)

            if !noteSegments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(noteSegments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case let .text(text):
                        Text(text)
                            .font(.system(size: 14))
                            .lineSpacing(6)
                            .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    case let .image(image):
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            }

            if let summary, !summary.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI 总结")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PanelCardTone.summary.accent(for: colorScheme))

                    Text(summary)
                        .font(.system(size: 13))
                        .lineSpacing(5)
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                }
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
        .background(colorScheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.16) : .white)
    }
}
