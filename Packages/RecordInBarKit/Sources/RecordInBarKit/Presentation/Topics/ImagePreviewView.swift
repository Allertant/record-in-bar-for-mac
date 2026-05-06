import AppKit
import SwiftUI

struct ImagePreviewView: View {
    @ObservedObject var state: ImagePreviewState
    @State private var currentScale: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0

    private var totalScale: CGFloat {
        max(0.3, min(currentScale * pinchScale, 8.0))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
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
                        .padding(.horizontal, 72)
                        .padding(.vertical, 24)
                        .gesture(
                            MagnifyGesture()
                                .updating($pinchScale) { value, state, _ in
                                    state = value.magnification
                                }
                                .onEnded { value in
                                    currentScale = max(0.3, min(currentScale * value.magnification, 8.0))
                                }
                        )
                }

                HStack {
                    previewNavButton(
                        systemName: "chevron.backward",
                        isEnabled: state.canGoPrevious,
                        action: state.onPrevious
                    )

                    Spacer()

                    previewNavButton(
                        systemName: "chevron.forward",
                        isEnabled: state.canGoNext,
                        action: state.onNext
                    )
                }
                .padding(.horizontal, 18)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    @ViewBuilder
    private func previewNavButton(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.45))
                .frame(width: 84, height: 84)
                .background(
                    Circle()
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.22))
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
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
