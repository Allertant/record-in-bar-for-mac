import AppKit
import SwiftUI

struct ObservableVerticalScrollView<Content: View>: NSViewControllerRepresentable {
    @Binding var contentOffsetY: CGFloat
    @Binding var restoreOffsetY: CGFloat?
    let showsIndicators: Bool
    let content: Content

    init(
        contentOffsetY: Binding<CGFloat>,
        restoreOffsetY: Binding<CGFloat?>,
        showsIndicators: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self._contentOffsetY = contentOffsetY
        self._restoreOffsetY = restoreOffsetY
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    func makeNSViewController(context: Context) -> ScrollContainerController<Content> {
        let controller = ScrollContainerController(rootView: content)
        controller.showsIndicators = showsIndicators
        controller.onOffsetChange = { offset in
            if abs(contentOffsetY - offset) > 0.5 {
                contentOffsetY = offset
            }
        }
        return controller
    }

    func updateNSViewController(_ controller: ScrollContainerController<Content>, context: Context) {
        controller.showsIndicators = showsIndicators
        controller.onOffsetChange = { offset in
            if abs(contentOffsetY - offset) > 0.5 {
                contentOffsetY = offset
            }
        }
        controller.update(rootView: content)

        if let restoreOffsetY {
            controller.restore(offsetY: restoreOffsetY) {
                self.restoreOffsetY = nil
                self.contentOffsetY = restoreOffsetY
            }
        }
    }
}

@MainActor
final class ScrollContainerController<Content: View>: NSViewController {
    private let scrollView = NSScrollView()
    private let hostingView: NSHostingView<Content>
    private var isRestoring = false

    var showsIndicators: Bool = false {
        didSet {
            scrollView.hasVerticalScroller = showsIndicators
            scrollView.autohidesScrollers = !showsIndicators
        }
    }

    var onOffsetChange: ((CGFloat) -> Void)?

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
        scrollView.hasVerticalScroller = showsIndicators
        scrollView.autohidesScrollers = !showsIndicators

        if let clipView = scrollView.contentView as NSClipView? {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contentBoundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }

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
        syncDocumentSize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func update(rootView: Content) {
        hostingView.rootView = rootView
        hostingView.layoutSubtreeIfNeeded()
        syncDocumentSize()
    }

    func restore(offsetY: CGFloat, completion: @escaping () -> Void) {
        guard scrollView.documentView != nil else {
            completion()
            return
        }

        syncDocumentSize()

        let maxOffset = max(0, hostingView.frame.height - scrollView.contentView.bounds.height)
        let targetY = min(max(0, offsetY), maxOffset)

        isRestoring = true
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        DispatchQueue.main.async { [weak self] in
            self?.isRestoring = false
            completion()
        }
    }

    @objc private func contentBoundsDidChange(_ notification: Notification) {
        guard !isRestoring else { return }
        onOffsetChange?(scrollView.contentView.bounds.origin.y)
    }

    private func syncDocumentSize() {
        let width = max(1, scrollView.contentSize.width)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: max(1, hostingView.frame.height))
        hostingView.layoutSubtreeIfNeeded()
        let measuredHeight = max(1, hostingView.fittingSize.height)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: measuredHeight)
    }
}
