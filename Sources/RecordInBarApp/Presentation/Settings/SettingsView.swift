import SwiftData
import SwiftUI

struct SettingsPageView: View {
    @Environment(\.modelContext) private var modelContext

    let settings: AppSettings?
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PanelPageHeader(title: "设置") {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(IconHoverButtonStyle())
            } trailing: {
                Color.clear.frame(width: 1, height: 1)
            }

            if let settings {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DeepSeek 配置")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CompactTextInput(title: "API Key", text: apiKeyBinding(for: settings))

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
            } else {
                ProgressView("正在加载设置...")
                    .task {
                        SettingsBootstrap.ensureDefaultSettings(in: modelContext)
                    }
            }
        }
    }

    private func apiKeyBinding(for settings: AppSettings) -> Binding<String> {
        Binding(
            get: { settings.deepSeekAPIKey },
            set: { newValue in
                settings.deepSeekAPIKey = newValue
                settings.updatedAt = .now
                try? modelContext.save()
            }
        )
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
