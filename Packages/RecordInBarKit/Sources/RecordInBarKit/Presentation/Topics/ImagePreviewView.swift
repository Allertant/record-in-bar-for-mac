import AppKit
import SwiftUI

struct ImagePreviewView: View {
    @ObservedObject var state: ImagePreviewState
    @State private var currentScale: CGFloat = 1.0
    @State private var isHoveringImage = false
    @GestureState private var pinchScale: CGFloat = 1.0

    private var totalScale: CGFloat {
        max(0.3, min(currentScale * pinchScale, 8.0))
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                let baseScale = min(
                    geo.size.width / max(state.image.size.width, 1),
                    geo.size.height / max(state.image.size.height, 1),
                    1
                )
                let displayWidth = max(120, state.image.size.width * baseScale * totalScale)
                let displayHeight = max(120, state.image.size.height * baseScale * totalScale)

                Image(nsImage: state.image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: displayWidth, height: displayHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(24)
                    .gesture(
                        MagnifyGesture()
                            .updating($pinchScale) { value, state, _ in
                                state = value.magnification
                            }
                            .onEnded { value in
                                currentScale = max(0.3, min(currentScale * value.magnification, 8.0))
                            }
                    )
                    .overlay(alignment: .leading) {
                        previewNavButton(
                            systemName: "chevron.backward",
                            isVisible: isHoveringImage,
                            isEnabled: state.canGoPrevious,
                            action: state.onPrevious
                        )
                        .padding(.leading, 20)
                    }
                    .overlay(alignment: .trailing) {
                        previewNavButton(
                            systemName: "chevron.forward",
                            isVisible: isHoveringImage,
                            isEnabled: state.canGoNext,
                            action: state.onNext
                        )
                        .padding(.trailing, 20)
                    }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active:
                            withAnimation(.easeOut(duration: 0.16)) {
                                isHoveringImage = true
                            }
                        case .ended:
                            withAnimation(.easeIn(duration: 0.18)) {
                                isHoveringImage = false
                            }
                        }
                    }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    @ViewBuilder
    private func previewNavButton(
        systemName: String,
        isVisible: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
                .frame(width: 46, height: 46)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible && isEnabled)
    }
}

@MainActor
final class ImagePreviewState: ObservableObject {
    @Published var image: NSImage = NSImage(size: NSSize(width: 1, height: 1))
    @Published var canGoPrevious = false
    @Published var canGoNext = false
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    func update(
        image: NSImage,
        canGoPrevious: Bool,
        canGoNext: Bool,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.image = image
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.onPrevious = onPrevious
        self.onNext = onNext
    }
}
