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
            .padding(isPrimary ? .horizontal : .all, isPrimary ? 14 : 10)
            .padding(isPrimary ? .vertical : .all, isPrimary ? 9 : 0)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(
                color: isHovered ? Color.black.opacity(0.18) : .clear,
                radius: isHovered ? 12 : 0,
                x: 0,
                y: isHovered ? 6 : 0
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var background: some View {
        Group {
            if isPrimary {
                Color.accentColor
                    .opacity(configuration.isPressed ? 0.75 : (isHovered ? 0.92 : 1))
            } else {
                Color.primary
                    .opacity(isHovered ? 0.08 : 0.04)
            }
        }
    }
}
