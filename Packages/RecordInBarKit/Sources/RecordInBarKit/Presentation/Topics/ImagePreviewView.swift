import AppKit
import SwiftUI

struct ImagePreviewView: View {
    @ObservedObject var state: ImagePreviewState

    var body: some View {
        ZStack {
            ZoomableImageView(image: state.image)

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

// MARK: - Zoomable NSView

struct ZoomableImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> ZoomableImageNSView {
        let view = ZoomableImageNSView()
        view.image = image
        return view
    }

    func updateNSView(_ nsView: ZoomableImageNSView, context: Context) {
        if nsView.image !== image {
            nsView.image = image
            nsView.resetZoom()
        }
    }
}

final class ZoomableImageNSView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    private var scale: CGFloat = 1.0
    private var offset: CGPoint = .zero
    private var isDragging = false
    private var lastDragPoint: CGPoint = .zero
    private var baseFitScale: CGFloat = 1.0

    private let minScale: CGFloat = 0.2
    private let maxScale: CGFloat = 10.0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        guard let image else { return }

        let fitScale = min(
            bounds.width / max(image.size.width, 1),
            bounds.height / max(image.size.height, 1),
            1
        )
        baseFitScale = fitScale

        let displayWidth = image.size.width * fitScale * scale
        let displayHeight = image.size.height * fitScale * scale
        let drawX = (bounds.width - displayWidth) / 2 + offset.x
        let drawY = (bounds.height - displayHeight) / 2 + offset.y

        image.draw(
            in: NSRect(x: drawX, y: drawY, width: displayWidth, height: displayHeight),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    // MARK: - Trackpad pinch zoom

    override func magnify(with event: NSEvent) {
        let newScale = clampScale(scale * (1.0 + event.magnification))
        let point = convert(event.locationInWindow, from: nil)

        let oldDisplayWidth = image!.size.width * baseFitScale * scale
        let oldDisplayHeight = image!.size.height * baseFitScale * scale
        let oldDrawX = (bounds.width - oldDisplayWidth) / 2 + offset.x
        let oldDrawY = (bounds.height - oldDisplayHeight) / 2 + offset.y
        let relX = (point.x - oldDrawX) / max(oldDisplayWidth, 1)
        let relY = (point.y - oldDrawY) / max(oldDisplayHeight, 1)

        scale = newScale

        let newDisplayWidth = image!.size.width * baseFitScale * scale
        let newDisplayHeight = image!.size.height * baseFitScale * scale
        let newDrawX = (bounds.width - newDisplayWidth) / 2 + offset.x
        let newDrawY = (bounds.height - newDisplayHeight) / 2 + offset.y

        offset.x += point.x - (newDrawX + relX * newDisplayWidth)
        offset.y += point.y - (newDrawY + relY * newDisplayHeight)

        needsDisplay = true
    }

    // MARK: - Scroll wheel zoom

    override func scrollWheel(with event: NSEvent) {
        guard event.deltaY != 0 else { return }

        let zoomFactor: CGFloat
        if event.hasPreciseScrollingDeltas {
            zoomFactor = 1.0 + event.deltaY * 0.003
        } else {
            zoomFactor = event.deltaY > 0 ? 1.1 : 0.9
        }

        let point = convert(event.locationInWindow, from: nil)
        zoomAt(point: point, factor: zoomFactor)
    }

    // MARK: - Drag to pan

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        lastDragPoint = point
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        offset.x += point.x - lastDragPoint.x
        offset.y += point.y - lastDragPoint.y
        lastDragPoint = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if event.clickCount == 2 {
            resetZoom()
        }
    }

    // MARK: - Helpers

    func resetZoom() {
        scale = 1.0
        offset = .zero
        needsDisplay = true
    }

    private func clampScale(_ s: CGFloat) -> CGFloat {
        max(minScale, min(s, maxScale))
    }

    private func zoomAt(point: CGPoint, factor: CGFloat) {
        guard let image else { return }

        let oldDisplayWidth = image.size.width * baseFitScale * scale
        let oldDisplayHeight = image.size.height * baseFitScale * scale
        let oldDrawX = (bounds.width - oldDisplayWidth) / 2 + offset.x
        let oldDrawY = (bounds.height - oldDisplayHeight) / 2 + offset.y
        let relX = (point.x - oldDrawX) / max(oldDisplayWidth, 1)
        let relY = (point.y - oldDrawY) / max(oldDisplayHeight, 1)

        let newScale = clampScale(scale * factor)

        let newDisplayWidth = image.size.width * baseFitScale * newScale
        let newDisplayHeight = image.size.height * baseFitScale * newScale
        let newDrawX = (bounds.width - newDisplayWidth) / 2 + offset.x
        let newDrawY = (bounds.height - newDisplayHeight) / 2 + offset.y

        offset.x += point.x - (newDrawX + relX * newDisplayWidth)
        offset.y += point.y - (newDrawY + relY * newDisplayHeight)

        scale = newScale
        needsDisplay = true
    }
}

// MARK: - State

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
