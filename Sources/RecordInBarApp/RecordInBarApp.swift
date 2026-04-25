import AppKit
import SwiftData
import SwiftUI

@main
struct RecordInBarApp: App {
    private let modelContainer = PersistenceController.shared.container

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("状态栏记录", systemImage: "rectangle.stack.badge.plus") {
            AppMenuRootView()
                .frame(width: 360, height: 520)
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
