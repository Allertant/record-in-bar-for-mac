import SwiftData

enum SettingsBootstrap {
    @MainActor
    static func ensureDefaultSettings(in context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()

        let existingSettings = (try? context.fetch(descriptor)) ?? []
        guard existingSettings.isEmpty else { return }

        context.insert(AppSettings())
        try? context.save()
    }
}
