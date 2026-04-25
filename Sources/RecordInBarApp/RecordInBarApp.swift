import AppKit
import Combine
import SwiftData
import SwiftUI

@MainActor
final class PopoverPinManager: ObservableObject {
    static let shared = PopoverPinManager()
    @Published var isPinned = false
}

@main
struct RecordInBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var pinWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var isTransitioning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.stack.badge.plus",
                accessibilityDescription: "状态栏记录"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.delegate = self

        let modelContainer = PersistenceController.shared.container
        popover.contentViewController = NSHostingController(
            rootView: AppMenuRootView()
                .modelContainer(modelContainer)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPopoverDidClose(_:)),
            name: NSPopover.didCloseNotification,
            object: popover
        )

        PopoverPinManager.shared.$isPinned
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPinned in
                if isPinned {
                    self?.transitionToPinnedWindow()
                } else {
                    self?.transitionToPopover()
                }
            }
            .store(in: &cancellables)

        self.popover = popover
    }

    // MARK: - Status bar toggle

    @MainActor @objc private func togglePopover() {
        if let window = pinWindow {
            window.close()
            return
        }

        guard let popover, let statusItem else { return }
        if popover.isShown {
            PopoverPinManager.shared.isPinned = false
            popover.close()
        } else {
            if let button = statusItem.button {
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    // MARK: - Popover delegate

    @MainActor @objc private func onPopoverDidClose(_ notification: Notification) {
        if !isTransitioning {
            NSApp.deactivate()
        }
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if isTransitioning { return true }
        return !PopoverPinManager.shared.isPinned
    }

    // MARK: - Window delegate

    func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard let window = notification.object as? NSWindow, window === pinWindow else { return }
            PopoverPinManager.shared.isPinned = false
        }
    }

    // MARK: - Transitions

    @MainActor private func transitionToPinnedWindow() {
        guard let popover, let hostingController = popover.contentViewController else { return }

        let popoverFrame = hostingController.view.window?.frame
            ?? NSRect(x: 200, y: 400, width: 360, height: 520)

        isTransitioning = true
        popover.contentViewController = nil
        popover.close()
        isTransitioning = false

        let window = NSWindow(
            contentRect: popoverFrame,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "状态栏记录"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 300, height: 300)
        window.level = .floating
        window.contentViewController = hostingController
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        pinWindow = window
    }

    @MainActor private func transitionToPopover() {
        guard let window = pinWindow, let hostingController = window.contentViewController else { return }

        window.contentViewController = nil
        window.close()
        pinWindow = nil

        guard let popover, let statusItem, let button = statusItem.button else { return }

        popover.contentSize = NSSize(width: 360, height: 520)
        popover.contentViewController = hostingController
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
