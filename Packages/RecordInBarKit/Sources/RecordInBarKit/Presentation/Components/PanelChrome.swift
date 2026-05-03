import SwiftUI

enum PanelCardTone {
    case neutral
    case create
    case historyBlue
    case historyGreen
    case historyOrange
    case historyRose
    case historySlate
    case editor
    case summary
    case settings

    var background: Color {
        background(for: .light)
    }

    var border: Color {
        border(for: .light)
    }

    var accent: Color {
        accent(for: .light)
    }

    func background(for scheme: ColorScheme) -> Color {
        switch self {
        case .neutral:
            scheme == .dark
                ? Color.white.opacity(0.08)
                : Color(nsColor: .controlBackgroundColor).opacity(0.72)
        case .create:
            scheme == .dark
                ? Color(red: 0.12, green: 0.28, blue: 0.24).opacity(0.85)
                : Color(red: 0.87, green: 0.95, blue: 0.93).opacity(0.92)
        case .historyBlue:
            scheme == .dark
                ? Color(red: 0.12, green: 0.18, blue: 0.32).opacity(0.85)
                : Color(red: 0.88, green: 0.93, blue: 0.99).opacity(0.9)
        case .historyGreen:
            scheme == .dark
                ? Color(red: 0.12, green: 0.25, blue: 0.16).opacity(0.85)
                : Color(red: 0.89, green: 0.96, blue: 0.91).opacity(0.9)
        case .historyOrange:
            scheme == .dark
                ? Color(red: 0.28, green: 0.18, blue: 0.1).opacity(0.85)
                : Color(red: 0.98, green: 0.93, blue: 0.86).opacity(0.92)
        case .historyRose:
            scheme == .dark
                ? Color(red: 0.26, green: 0.12, blue: 0.18).opacity(0.85)
                : Color(red: 0.98, green: 0.9, blue: 0.92).opacity(0.9)
        case .historySlate:
            scheme == .dark
                ? Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.85)
                : Color(red: 0.92, green: 0.94, blue: 0.97).opacity(0.9)
        case .editor:
            scheme == .dark
                ? Color(red: 0.22, green: 0.18, blue: 0.12).opacity(0.85)
                : Color(red: 0.96, green: 0.94, blue: 0.9).opacity(0.9)
        case .summary:
            scheme == .dark
                ? Color(red: 0.25, green: 0.2, blue: 0.1).opacity(0.9)
                : Color(red: 0.99, green: 0.95, blue: 0.84).opacity(0.94)
        case .settings:
            scheme == .dark
                ? Color(red: 0.12, green: 0.16, blue: 0.24).opacity(0.85)
                : Color(red: 0.92, green: 0.95, blue: 0.98).opacity(0.9)
        }
    }

    func border(for scheme: ColorScheme) -> Color {
        switch self {
        case .neutral:
            scheme == .dark
                ? Color.white.opacity(0.1)
                : Color.black.opacity(0.06)
        case .create:
            scheme == .dark
                ? Color(red: 0.27, green: 0.62, blue: 0.52).opacity(0.35)
                : Color(red: 0.27, green: 0.62, blue: 0.52).opacity(0.22)
        case .historyBlue:
            scheme == .dark
                ? Color(red: 0.3, green: 0.5, blue: 0.83).opacity(0.35)
                : Color(red: 0.3, green: 0.5, blue: 0.83).opacity(0.2)
        case .historyGreen:
            scheme == .dark
                ? Color(red: 0.24, green: 0.62, blue: 0.35).opacity(0.35)
                : Color(red: 0.24, green: 0.62, blue: 0.35).opacity(0.2)
        case .historyOrange:
            scheme == .dark
                ? Color(red: 0.82, green: 0.54, blue: 0.18).opacity(0.35)
                : Color(red: 0.82, green: 0.54, blue: 0.18).opacity(0.2)
        case .historyRose:
            scheme == .dark
                ? Color(red: 0.76, green: 0.34, blue: 0.46).opacity(0.35)
                : Color(red: 0.76, green: 0.34, blue: 0.46).opacity(0.2)
        case .historySlate:
            scheme == .dark
                ? Color(red: 0.39, green: 0.47, blue: 0.58).opacity(0.3)
                : Color(red: 0.39, green: 0.47, blue: 0.58).opacity(0.18)
        case .editor:
            scheme == .dark
                ? Color(red: 0.62, green: 0.48, blue: 0.22).opacity(0.3)
                : Color(red: 0.62, green: 0.48, blue: 0.22).opacity(0.18)
        case .summary:
            scheme == .dark
                ? Color(red: 0.82, green: 0.61, blue: 0.16).opacity(0.35)
                : Color(red: 0.82, green: 0.61, blue: 0.16).opacity(0.22)
        case .settings:
            scheme == .dark
                ? Color(red: 0.29, green: 0.48, blue: 0.72).opacity(0.3)
                : Color(red: 0.29, green: 0.48, blue: 0.72).opacity(0.18)
        }
    }

    func accent(for scheme: ColorScheme) -> Color {
        switch self {
        case .neutral:
            .secondary
        case .create:
            scheme == .dark
                ? Color(red: 0.4, green: 0.78, blue: 0.65)
                : Color(red: 0.19, green: 0.53, blue: 0.42)
        case .historyBlue:
            scheme == .dark
                ? Color(red: 0.45, green: 0.65, blue: 0.95)
                : Color(red: 0.24, green: 0.46, blue: 0.78)
        case .historyGreen:
            scheme == .dark
                ? Color(red: 0.4, green: 0.78, blue: 0.48)
                : Color(red: 0.2, green: 0.58, blue: 0.29)
        case .historyOrange:
            scheme == .dark
                ? Color(red: 0.95, green: 0.65, blue: 0.3)
                : Color(red: 0.75, green: 0.46, blue: 0.14)
        case .historyRose:
            scheme == .dark
                ? Color(red: 0.9, green: 0.45, blue: 0.58)
                : Color(red: 0.72, green: 0.28, blue: 0.42)
        case .historySlate:
            scheme == .dark
                ? Color(red: 0.55, green: 0.62, blue: 0.72)
                : Color(red: 0.34, green: 0.42, blue: 0.53)
        case .editor:
            scheme == .dark
                ? Color(red: 0.78, green: 0.62, blue: 0.35)
                : Color(red: 0.56, green: 0.42, blue: 0.18)
        case .summary:
            scheme == .dark
                ? Color(red: 0.92, green: 0.72, blue: 0.25)
                : Color(red: 0.74, green: 0.52, blue: 0.08)
        case .settings:
            scheme == .dark
                ? Color(red: 0.45, green: 0.62, blue: 0.88)
                : Color(red: 0.25, green: 0.42, blue: 0.69)
        }
    }
}

struct PanelCard<Content: View>: View {
    let padding: CGFloat
    let tone: PanelCardTone
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    init(padding: CGFloat = 10, tone: PanelCardTone = .neutral, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(tone.background(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tone.border(for: colorScheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PanelPageHeader<Leading: View, Middle: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let middle: Middle
    @ViewBuilder let trailing: Trailing
    let title: String

    init(
        title: String,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder middle: () -> Middle = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.leading = leading()
        self.middle = middle()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                leading
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    
                    middle
                }
                
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
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let keywords: [String]
    @Binding var text: String

    @State private var currentIndex = 0
    @State private var keywordOpacity: Double = 1.0
    @State private var timer: Timer?

    private var currentKeyword: String? {
        guard !keywords.isEmpty else { return nil }
        return keywords[currentIndex % keywords.count]
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .leading) {
                TextField("", text: $text, prompt: Text(currentKeyword ?? title)
                    .foregroundStyle(.tertiary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        if text.isEmpty, let keyword = currentKeyword {
                            text = keyword
                        }
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(keywordOpacity)
        .animation(.easeInOut(duration: 0.3), value: keywordOpacity)
        .onChange(of: text) { _, newValue in
            if newValue.isEmpty {
                startTimer()
            } else {
                stopTimer()
            }
        }
        .onChange(of: keywords) { _, newValue in
            if !newValue.isEmpty && text.isEmpty {
                currentIndex = Int.random(in: 0..<newValue.count)
                startTimer()
            }
        }
        .onAppear {
            if !keywords.isEmpty && text.isEmpty {
                currentIndex = Int.random(in: 0..<keywords.count)
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        stopTimer()
        guard !keywords.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                keywordOpacity = 0
                try? await Task.sleep(for: .milliseconds(300))
                currentIndex = (currentIndex + 1) % keywords.count
                keywordOpacity = 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct CompactTextInput: View {
    @Environment(\.colorScheme) private var colorScheme
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
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct CompactSecureInput: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            SecureField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
