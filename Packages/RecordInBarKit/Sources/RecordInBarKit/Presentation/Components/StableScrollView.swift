import AppKit
import SwiftUI

/// NSScrollView wrapper with no bindings.
/// Saves and restores scroll offset on content updates to prevent position drift.
struct StableScrollView<Content: View>: NSViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSViewController(context: Context) -> StableScrollController<Content> {
        StableScrollController(rootView: content)
    }

    func updateNSViewController(_ controller: StableScrollController<Content>, context: Context) {
        controller.update(rootView: content)
    }
}

@MainActor
final class StableScrollController<Content: View>: NSViewController {
    private let scrollView = NSScrollView()
    private let hostingView: NSHostingView<Content>
    private var pendingRestoreY: CGFloat?
    private var hasScheduledDocumentSizeSync = false

    init(rootView: Content) {
        hostingView = NSHostingView(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true

        hostingView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = hostingView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        scheduleDocumentSizeSync()
    }

    func update(rootView: Content) {
        let savedY = scrollView.contentView.bounds.origin.y
        hostingView.rootView = rootView
        pendingRestoreY = savedY
        scheduleDocumentSizeSync()
    }

    private func syncDocumentSize() {
        let width = max(1, scrollView.contentSize.width)
        let currentHeight = max(1, hostingView.frame.height)
        if abs(hostingView.frame.width - width) > 0.5 {
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: currentHeight)
        }

        let measuredHeight = max(1, hostingView.fittingSize.height)
        if abs(hostingView.frame.width - width) > 0.5 || abs(hostingView.frame.height - measuredHeight) > 0.5 {
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: measuredHeight)
        }

        if let y = pendingRestoreY {
            pendingRestoreY = nil
            restoreScroll(y)
        }
    }

    private func scheduleDocumentSizeSync() {
        guard !hasScheduledDocumentSizeSync else { return }
        hasScheduledDocumentSizeSync = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasScheduledDocumentSizeSync = false
            self.syncDocumentSize()
        }
    }

    private func restoreScroll(_ y: CGFloat) {
        let clipView = scrollView.contentView
        let maxOffset = max(0, hostingView.frame.height - clipView.bounds.height)
        let targetY = min(max(0, y), maxOffset)
        clipView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
        ensureCursorVisible()
    }

    private func ensureCursorVisible() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let container = textView.textContainer,
              let manager = textView.layoutManager else { return }

        let selection = textView.selectedRange()
        guard selection.location != NSNotFound else { return }

        manager.ensureLayout(for: container)
        let glyphRect: NSRect
        if selection.length == 0, selection.location == (textView.textStorage?.length ?? 0), !manager.extraLineFragmentRect.isEmpty {
            glyphRect = manager.extraLineFragmentRect
        } else {
            let characterLocation = max(0, min(selection.location, max(0, (textView.textStorage?.length ?? 1) - 1)))
            let glyphIndex = manager.glyphIndexForCharacter(at: characterLocation)
            glyphRect = manager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        }
        let textContainerOrigin = textView.textContainerOrigin
        let cursorInTextView = glyphRect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        let cursorInHost = textView.convert(cursorInTextView, to: hostingView)

        let clipView = scrollView.contentView
        let visibleRect = clipView.bounds
        let padding: CGFloat = 20

        if cursorInHost.maxY > visibleRect.maxY - padding {
            let newY = min(cursorInHost.maxY - visibleRect.height + padding, hostingView.frame.height - visibleRect.height)
            clipView.scroll(to: NSPoint(x: 0, y: max(0, newY)))
            scrollView.reflectScrolledClipView(clipView)
        } else if cursorInHost.minY < visibleRect.minY + padding {
            clipView.scroll(to: NSPoint(x: 0, y: max(0, cursorInHost.minY - padding)))
            scrollView.reflectScrolledClipView(clipView)
        }
    }
}
