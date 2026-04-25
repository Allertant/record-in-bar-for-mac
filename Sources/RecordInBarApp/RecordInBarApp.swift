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
        MenuBarExtra("Record in Bar", systemImage: "rectangle.stack.badge.plus") {
            AppMenuRootView()
                .frame(width: 380, height: 560)
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
