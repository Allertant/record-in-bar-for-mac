import SwiftData
import SwiftUI

struct SettingsPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let settings: AppSettings?
    let onBack: () -> Void

    @State private var apiKeyDraft = ""
    @State private var didLoadDraft = false
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var saveMessage = ""
    @State private var isMigratingStorage = false
    @State private var storagePathDisplay = ""
    @State private var isShowingFullStoragePath = false
    @State private var storagePathToast = ""

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
                        deepSeekSection(for: settings)
                        appearanceSection(for: settings)
                        imageStorageSection(for: settings)
                    }
                    .padding(12)
                }
                .scrollIndicators(.hidden)
                .task(id: settings.persistentModelID) {
                    guard !didLoadDraft else { return }
                    settings.normalizeAPIKeyStorage()
                    apiKeyDraft = settings.deepSeekAPIKey
                    storagePathDisplay = ImageStorage.currentBasePath()
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

    // MARK: - DeepSeek

    @ViewBuilder
    private func deepSeekSection(for settings: AppSettings) -> some View {
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

                Toggle("分享图片包含 AI 总结", isOn: Binding<Bool>(
                    get: { settings.includeAISummaryInShareImage ?? true },
                    set: { settings.includeAISummaryInShareImage = $0; settings.updatedAt = .now; try? modelContext.save() }
                ))
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

    // MARK: - Appearance

    @ViewBuilder
    private func appearanceSection(for settings: AppSettings) -> some View {
        Text("外观")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)

        PanelCard(tone: .settings) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("模式", selection: Binding<Int>(
                    get: {
                        switch settings.appearanceMode {
                        case "light": return 1
                        case "dark": return 2
                        default: return 0
                        }
                    },
                    set: { index in
                        switch index {
                        case 1: settings.appearanceMode = "light"
                        case 2: settings.appearanceMode = "dark"
                        default: settings.appearanceMode = nil
                        }
                        settings.updatedAt = .now
                        try? modelContext.save()
                    }
                )) {
                    Text("跟随系统").tag(0)
                    Text("浅色").tag(1)
                    Text("深色").tag(2)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Image Storage

    @ViewBuilder
    private func imageStorageSection(for settings: AppSettings) -> some View {
        Text("图片存储")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)

        PanelCard(tone: .settings) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(storagePathDisplay)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(storagePathDisplay)

                    Button(isShowingFullStoragePath ? "收起" : "查看") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isShowingFullStoragePath.toggle()
                        }
                    }
                    .buttonStyle(IconProminentButtonStyle())
                    .disabled(isMigratingStorage)

                    Button("选择目录") {
                        chooseImageStorageDirectory(for: settings)
                    }
                    .buttonStyle(IconProminentButtonStyle())
                    .disabled(isMigratingStorage)
                }

                if isShowingFullStoragePath {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ImageStorage.currentBasePath())
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button("复制路径") {
                                copyStoragePath()
                            }
                            .buttonStyle(IconProminentButtonStyle())

                            Button("打开目录") {
                                openStoragePath()
                            }
                            .buttonStyle(IconProminentButtonStyle())
                        }

                        if !storagePathToast.isEmpty {
                            Text(storagePathToast)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if isMigratingStorage {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在迁移图片...")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                if (settings.imageStoragePath ?? "").isEmpty {
                    Text("当前使用默认存储位置")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Actions

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

    @MainActor
    private func chooseImageStorageDirectory(for settings: AppSettings) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "选择"
        panel.message = "选择图片存储目录"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let oldPath = ImageStorage.currentBasePath()
        let newPath = url.path

        isMigratingStorage = true

        Task { @MainActor in
            let oldDir = URL(fileURLWithPath: oldPath)
            let newDir = url.appendingPathComponent(ImageStorage.rootDirectoryName, isDirectory: true)

            do {
                try ImageStorage.migrateImages(from: oldDir, to: newDir)
                settings.imageStoragePath = newPath
                ImageStorage.configuredPath = newPath
                ImageStorage.configuredPath = newPath
                storagePathDisplay = ImageStorage.currentBasePath()
                settings.updatedAt = .now
                try? modelContext.save()
            } catch {
                print("图片迁移失败：\(error)")
            }

            isMigratingStorage = false
        }
    }

    @MainActor
    private func copyStoragePath() {
        let path = ImageStorage.currentBasePath()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
        showStoragePathToast("路径已复制")
    }

    @MainActor
    private func openStoragePath() {
        let url = URL(fileURLWithPath: ImageStorage.currentBasePath(), isDirectory: true)
        NSWorkspace.shared.open(url)
        showStoragePathToast("已在 Finder 中打开")
    }

    @MainActor
    private func showStoragePathToast(_ message: String) {
        storagePathToast = message
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            if storagePathToast == message {
                storagePathToast = ""
            }
        }
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
