import Foundation
import SwiftData
import Testing
@testable import RecordInBarKit

@MainActor
struct RecordInBarAppTests {
    @Test
    func settingsBootstrapCreatesSingleton() throws {
        let persistence = SharedPersistenceController(inMemory: true)
        let context = ModelContext(persistence.container)

        SettingsBootstrap.ensureDefaultSettings(in: context)
        SettingsBootstrap.ensureDefaultSettings(in: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.count == 1)
        #expect(settings.first?.selectedModel == "deepseek-v4-flash")
    }

    @Test
    func apiKeyIsStoredAsBase64() {
        let settings = AppSettings(deepSeekAPIKey: "sk-test-value")

        #expect(settings.deepSeekAPIKey == "sk-test-value")
        #expect(settings.deepSeekAPIKeyBase64 != "sk-test-value")
        #expect(settings.deepSeekAPIKeyBase64 == Data("sk-test-value".utf8).base64EncodedString())
    }

    @Test
    func plaintextAPIKeyIsNormalizedToBase64() {
        let settings = AppSettings()
        settings.deepSeekAPIKeyBase64 = "sk-plain-text"

        settings.normalizeAPIKeyStorage()

        #expect(settings.deepSeekAPIKey == "sk-plain-text")
        #expect(settings.deepSeekAPIKeyBase64 == Data("sk-plain-text".utf8).base64EncodedString())
        #expect(settings.hasEncodedAPIKey)
    }
}
