import SwiftUI

struct PrimaryHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(configuration: configuration, isPrimary: true)
    }
}

struct IconHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(configuration: configuration, isPrimary: false)
    }
}

private struct HoverButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let isPrimary: Bool

    @State private var isHovered = false

    var body: some View {
        configuration.label
            .padding(isPrimary ? .horizontal : .all, isPrimary ? 10 : 6)
            .padding(isPrimary ? .vertical : .all, isPrimary ? 6 : 0)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(
                color: isHovered ? Color.black.opacity(0.12) : .clear,
                radius: isHovered ? 6 : 0,
                x: 0,
                y: isHovered ? 2 : 0
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var background: some View {
        Group {
            if isPrimary {
                Color.accentColor
                    .opacity(configuration.isPressed ? 0.8 : (isHovered ? 0.92 : 0.88))
            } else {
                Color.primary.opacity(isHovered ? 0.075 : 0.001)
            }
        }
    }
}
