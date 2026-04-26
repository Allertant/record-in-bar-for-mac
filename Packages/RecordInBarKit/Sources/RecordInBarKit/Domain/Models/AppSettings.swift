import Foundation
import SwiftData

@Model
public final class AppSettings {
    public static let singletonKey = "default"

    @Attribute(.unique) public var profile: String
    public var deepSeekAPIKeyBase64: String
    public var selectedModel: String
    public var thinkingEnabled: Bool
    public var reasoningEffort: String
    public var updatedAt: Date

    public init(
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

    public var deepSeekAPIKey: String {
        get { Base64Coder.decode(deepSeekAPIKeyBase64) }
        set { deepSeekAPIKeyBase64 = Base64Coder.encode(newValue) }
    }

    public var hasEncodedAPIKey: Bool {
        Base64Coder.isEncoded(deepSeekAPIKeyBase64)
    }

    func normalizeAPIKeyStorage() {
        guard !deepSeekAPIKeyBase64.isEmpty else { return }
        guard !hasEncodedAPIKey else { return }
        deepSeekAPIKeyBase64 = Base64Coder.encode(deepSeekAPIKeyBase64)
    }
}
