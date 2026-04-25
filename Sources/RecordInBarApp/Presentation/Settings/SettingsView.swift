import SwiftData
import SwiftUI

struct SettingsPageView: View {
    @Environment(\.modelContext) private var modelContext

    let settings: AppSettings?
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label("返回", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(IconHoverButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            if let settings {
                Form {
                    Section("DeepSeek 配置") {
                        SecureField("API Key", text: apiKeyBinding(for: settings))
                            .textFieldStyle(.roundedBorder)

                        Picker("模型", selection: binding(for: settings, keyPath: \.selectedModel)) {
                            Text("极速版（deepseek-v4-flash）").tag("deepseek-v4-flash")
                            Text("专业版（deepseek-v4-pro）").tag("deepseek-v4-pro")
                        }

                        Toggle("启用思考模式", isOn: binding(for: settings, keyPath: \.thinkingEnabled))

                        Picker("推理强度", selection: binding(for: settings, keyPath: \.reasoningEffort)) {
                            Text("低").tag("low")
                            Text("中").tag("medium")
                            Text("高").tag("high")
                        }
                    }
                }
                .formStyle(.grouped)
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
