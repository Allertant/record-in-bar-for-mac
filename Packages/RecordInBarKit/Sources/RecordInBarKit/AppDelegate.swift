import AppKit
import Combine
import SwiftData
import SwiftUI

extension Notification.Name {
    static let escKeyPressed = Notification.Name("escKeyPressed")
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var pinWindow: NSWindow?
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var isTransitioning = false

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.stack.badge.plus",
                accessibilityDescription: "状态栏记录"
            )
            button.action = #selector(handleStatusItemEvent)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self

        let modelContainer = PersistenceController.shared.container
        popover.contentViewController = NSHostingController(
            rootView: AppMenuRootView()
                .modelContainer(modelContainer)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPopoverDidShow(_:)),
            name: NSPopover.didShowNotification,
            object: popover
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

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { // ESC key
                if self.popover?.isShown == true {
                    NotificationCenter.default.post(name: .escKeyPressed, object: nil)
                }
            }
            return event
        }

        self.popover = popover
    }

    // MARK: - Status bar toggle

    @objc private func handleStatusItemEvent() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.maxY),
            in: button
        )
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func togglePopover() {
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

    // MARK: - Popover notifications & monitoring

    @objc private func onPopoverDidShow(_ notification: Notification) {
        startMonitoring()
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                if event.keyCode == 53 { // ESC key
                    if self.popover?.isShown == true {
                        NotificationCenter.default.post(name: .escKeyPressed, object: nil)
                    }
                }
                return event
            }
        }
    }

    @objc private func onPopoverDidClose(_ notification: Notification) {
        stopMonitoring()
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if !isTransitioning {
            NSApp.deactivate()
        }
    }

    private func startMonitoring() {
        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                Task { @MainActor in
                    self?.maybeClosePopover(event: event)
                }
            }
        }
    }

    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func maybeClosePopover(event: NSEvent) {
        guard let popover = popover, popover.isShown, !PopoverPinManager.shared.isPinned else { return }

        let mouseLocation = NSEvent.mouseLocation // Screen coordinates (bottom-left origin)

        // 1. If click is inside the popover window, don't close.
        if let window = popover.contentViewController?.view.window {
            if NSMouseInRect(mouseLocation, window.frame, false) {
                return
            }
        }

        // 2. If click is on the status bar button, let togglePopover handle it.
        if let button = statusItem?.button, let window = button.window {
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            let buttonFrameInScreen = window.convertToScreen(buttonFrameInWindow)
            if NSMouseInRect(mouseLocation, buttonFrameInScreen, false) {
                return
            }
        }

        popover.close()
    }

    // MARK: - Popover delegate

    public func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if isTransitioning { return true }
        return !PopoverPinManager.shared.isPinned
    }

    // MARK: - Window delegate

    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === pinWindow else { return }
        PopoverPinManager.shared.isPinned = false
    }

    // MARK: - Transitions

    private func transitionToPinnedWindow() {
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

    private func transitionToPopover() {
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
