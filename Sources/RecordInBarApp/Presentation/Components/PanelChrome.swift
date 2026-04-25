import SwiftUI

struct PanelCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(padding: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PanelPageHeader<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    let title: String

    init(
        title: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                leading
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                trailing
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
        }
    }
}

struct CompactSearchField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CompactTextInput: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("", text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(lineLimit)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
