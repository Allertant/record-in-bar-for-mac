import Foundation
import SwiftData

@Model
final class AppSettings {
    static let singletonKey = "default"

    @Attribute(.unique) var profile: String
    var deepSeekAPIKeyBase64: String
    var selectedModel: String
    var thinkingEnabled: Bool
    var reasoningEffort: String
    var updatedAt: Date

    init(
        profile: String = AppSettings.singletonKey,
        deepSeekAPIKey: String = "",
        selectedModel: String = "deepseek-v4-flash",
        thinkingEnabled: Bool = false,
        reasoningEffort: String = "high",
        updatedAt: Date = .now
    ) {
        self.profile = profile
        self.deepSeekAPIKeyBase64 = Base64Coder.encode(deepSeekAPIKey)
        self.selectedModel = selectedModel
        self.thinkingEnabled = thinkingEnabled
        self.reasoningEffort = reasoningEffort
        self.updatedAt = updatedAt
    }

    var deepSeekAPIKey: String {
        get { Base64Coder.decode(deepSeekAPIKeyBase64) }
        set { deepSeekAPIKeyBase64 = Base64Coder.encode(newValue) }
    }
}
