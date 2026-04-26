import SwiftUI
import RecordInBarKit

@main
struct RecordInBar: App {
    @NSApplicationDelegateAdaptor(RecordInBarKit.AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
