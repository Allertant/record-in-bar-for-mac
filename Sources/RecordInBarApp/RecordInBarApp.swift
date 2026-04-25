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

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

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
                .frame(width: 360, height: 520)
                .modelContainer(modelContainer)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPopoverDidClose(_:)),
            name: NSPopover.didCloseNotification,
            object: popover
        )

        PopoverPinManager.shared.$isPinned
            .sink { [weak self] isPinned in
                self?.popover?.behavior = isPinned ? .applicationDefined : .transient
            }
            .store(in: &cancellables)

        self.popover = popover
    }

    @MainActor @objc private func togglePopover() {
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

    @MainActor @objc private func onPopoverDidClose(_ notification: Notification) {
        NSApp.deactivate()
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        !PopoverPinManager.shared.isPinned
    }
}
