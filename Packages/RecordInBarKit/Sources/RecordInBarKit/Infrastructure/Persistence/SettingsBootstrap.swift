import SwiftData

enum SettingsBootstrap {
    @MainActor
    static func ensureDefaultSettings(in context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()

        let existingSettings = (try? context.fetch(descriptor)) ?? []
        if let existing = existingSettings.first {
            let before = existing.deepSeekAPIKeyBase64
            existing.normalizeAPIKeyStorage()
            if existing.deepSeekAPIKeyBase64 != before {
                existing.updatedAt = .now
                try? context.save()
            }
            ImageStorage.configuredPath = existing.imageStoragePath ?? ""
            return
        }

        context.insert(AppSettings())
        try? context.save()
    }
}
