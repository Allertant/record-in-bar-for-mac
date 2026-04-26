import SwiftData
import SwiftUI

struct SettingsPageView: View {
    @Environment(\.modelContext) private var modelContext

    let settings: AppSettings?
    let onBack: () -> Void

    @State private var apiKeyDraft = ""
    @State private var didLoadDraft = false
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var saveMessage = ""

    private let deepSeekClient = DeepSeekClient()

    var body: some View {
        VStack(spacing: 0) {
            PanelPageHeader(title: "设置") {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(IconHoverButtonStyle())
            } middle: {
                EmptyView()
            } trailing: {
                Color.clear.frame(width: 1, height: 1)
            }

            if let settings {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DeepSeek 配置")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        PanelCard(tone: .settings) {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactSecureInput(title: "API Key", text: $apiKeyDraft)

                                HStack(spacing: 8) {
                                    Button("保存") {
                                        saveAPIKey(for: settings)
                                    }
                                    .buttonStyle(PrimaryHoverButtonStyle())
                                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                    Button(isValidating ? "验证中..." : "验证") {
                                        Task {
                                            await validateAPIKey()
                                        }
                                    }
                                    .buttonStyle(IconProminentButtonStyle())
                                    .disabled(isValidating || apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                    if !saveMessage.isEmpty {
                                        Text(saveMessage)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.green)
                                    }
                                }

                                if !validationMessage.isEmpty {
                                    Text(validationMessage)
                                        .font(.system(size: 11))
                                        .foregroundStyle(validationMessage.hasPrefix("验证通过") ? .green : .secondary)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("模型")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)

                                    Picker("模型", selection: binding(for: settings, keyPath: \.selectedModel)) {
                                        Text("极速版（deepseek-v4-flash）").tag("deepseek-v4-flash")
                                        Text("专业版（deepseek-v4-pro）").tag("deepseek-v4-pro")
                                    }
                                    .pickerStyle(.menu)
                                }

                                Toggle("启用思考模式", isOn: binding(for: settings, keyPath: \.thinkingEnabled))
                                    .font(.system(size: 12))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("推理强度")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)

                                    Picker("推理强度", selection: binding(for: settings, keyPath: \.reasoningEffort)) {
                                        Text("低").tag("low")
                                        Text("中").tag("medium")
                                        Text("高").tag("high")
                                    }
                                    .pickerStyle(.segmented)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .scrollIndicators(.hidden)
                .task(id: settings.persistentModelID) {
                    guard !didLoadDraft else { return }
                    settings.normalizeAPIKeyStorage()
                    apiKeyDraft = settings.deepSeekAPIKey
                    didLoadDraft = true
                    try? modelContext.save()
                }
            } else {
                ProgressView("正在加载设置...")
                    .task {
                        SettingsBootstrap.ensureDefaultSettings(in: modelContext)
                    }
            }
        }
    }

    @MainActor
    private func saveAPIKey(for settings: AppSettings) {
        settings.deepSeekAPIKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.normalizeAPIKeyStorage()
        settings.updatedAt = .now
        try? modelContext.save()
        saveMessage = "已保存"
        validationMessage = ""
    }

    @MainActor
    private func validateAPIKey() async {
        isValidating = true
        saveMessage = ""

        do {
            try await deepSeekClient.validateAPIKey(apiKeyDraft)
            validationMessage = "验证通过：API Key 可用"
        } catch {
            validationMessage = "验证失败：\(error.localizedDescription)"
        }

        isValidating = false
    }

    private func binding<Value>(for settings: AppSettings, keyPath: ReferenceWritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                settings.updatedAt = .now
                try? modelContext.save()
            }
        )
    }
}

struct SettingsView: View {
    var body: some View {
        EmptyView()
    }
}

private struct IconProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
