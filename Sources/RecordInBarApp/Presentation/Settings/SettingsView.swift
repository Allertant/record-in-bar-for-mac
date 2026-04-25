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
                    Label("Back", systemImage: "chevron.left")
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
                    Section("DeepSeek") {
                        SecureField("API Key", text: apiKeyBinding(for: settings))
                            .textFieldStyle(.roundedBorder)

                        Picker("Model", selection: binding(for: settings, keyPath: \.selectedModel)) {
                            Text("deepseek-v4-flash").tag("deepseek-v4-flash")
                            Text("deepseek-v4-pro").tag("deepseek-v4-pro")
                        }

                        Toggle("Enable Thinking", isOn: binding(for: settings, keyPath: \.thinkingEnabled))

                        Picker("Reasoning Effort", selection: binding(for: settings, keyPath: \.reasoningEffort)) {
                            Text("low").tag("low")
                            Text("medium").tag("medium")
                            Text("high").tag("high")
                        }
                    }

                    Section("Storage") {
                        Text("API Key is stored locally after Base64 encoding.")
                            .foregroundStyle(.secondary)
                        Text("Topics and notes are saved locally in real time.")
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
            } else {
                ProgressView("Loading Settings...")
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
