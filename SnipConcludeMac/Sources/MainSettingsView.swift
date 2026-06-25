import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsTab: String, CaseIterable, Identifiable {
    case welcome = "欢迎"
    case general = "通用"
    case control = "控制"
    case provider = "模型提供商"
    case custom = "自定义"
    case about = "关于"

    var id: String { rawValue }
}

struct MainSettingsView: View {
    @State private var draft: AppSettings
    @State private var selectedTab: SettingsTab = .welcome
    @State private var isAddingModel = false
    @State private var editingModelProfileID: String?
    @State private var newModelProfile = ModelProfile(modelName: "", baseURL: "http://127.0.0.1:1234")
    @State private var isEditingAction = false
    @State private var editingActionProfileID: String?
    @State private var actionDraft = AIActionProfile(name: "", systemImage: "sparkles", prompt: "")
    let statusText: String
    let onStartCapture: () -> Void
    let onSaveSettings: (AppSettings) -> Void
    let onQuit: () -> Void

    init(
        settings: AppSettings,
        statusText: String,
        onStartCapture: @escaping () -> Void,
        onSaveSettings: @escaping (AppSettings) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self._draft = State(initialValue: settings)
        self.statusText = statusText
        self.onStartCapture = onStartCapture
        self.onSaveSettings = onSaveSettings
        self.onQuit = onQuit
    }

    var body: some View {
        VStack(spacing: 8) {
            tabRow
                .padding(.horizontal, 12)
                .padding(.top, 10)

            VStack(spacing: 0) {
                Divider()
                currentTab
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
            }
            .padding(.horizontal, 12)

            HStack {
                Button("开始截图") { onStartCapture() }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button("保存") { onSaveSettings(draft) }
                    .buttonStyle(.borderedProminent)
                Button("退出") { onQuit() }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .frame(minWidth: 500, idealWidth: 560, minHeight: 360, idealHeight: 410)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var tabRow: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(selectedTab == tab ? Color.accentColor : Color(nsColor: .controlColor))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var currentTab: some View {
        switch selectedTab {
        case .welcome:
            welcomeTab
        case .general:
            generalTab
        case .control:
            controlTab
        case .provider:
            providerTab
        case .custom:
            customTab
        case .about:
            aboutTab
        }
    }

    private var welcomeTab: some View {
        HStack(spacing: 0) {
            // Left: brand & info
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipWise")
                        .font(.system(size: 22, weight: .bold))
                    Text("截图智读助手")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Text("按下全局快捷键截图，调用本地视觉语言模型\n进行翻译、OCR 识别或智能总结。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)

                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )

                Spacer()
            }
            .padding(18)

            Spacer()

            // Right: decorative icon
            VStack {
                Spacer()
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.5)
                    .padding(.trailing, 24)
                    .padding(.bottom, 18)
            }
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("启动时显示主窗口", isOn: $draft.showControlWindowOnStartup)

            Stepper(value: $draft.resultPanelHeight, in: 120...600, step: 20) {
                Text("结果面板高度：\(draft.resultPanelHeight) px")
            }

            Stepper(value: $draft.requestTimeoutSeconds, in: 10...600, step: 10) {
                Text("AI 请求超时：\(draft.requestTimeoutSeconds) 秒")
            }

            HStack(spacing: 10) {
                Text("截图保存目录")
                    .foregroundStyle(.secondary)
                TextField("", text: $draft.saveDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                Button("浏览") { chooseSaveDirectory() }
            }

            Spacer()
        }
        .padding(18)
    }

    private var controlTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("截图快捷键")
                    .font(.system(size: 16, weight: .semibold))
                Text("选择一个修饰键组合，再输入一个字母键。保存后会重新注册快捷键。")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    modifierToggle("Control", isOn: $draft.captureHotkey.control)
                    modifierToggle("Shift", isOn: $draft.captureHotkey.shift)
                    modifierToggle("Option", isOn: $draft.captureHotkey.option)
                    modifierToggle("Command", isOn: $draft.captureHotkey.command)
                }

                HStack(spacing: 10) {
                    Text("按键")
                        .foregroundStyle(.secondary)
                    TextField("A", text: $draft.captureHotkey.key)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .onChange(of: draft.captureHotkey.key) { newValue in
                            draft.captureHotkey.key = String(newValue.prefix(1)).lowercased()
                        }
                    Text("当前：\(draft.captureHotkey.displayText)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(18)
    }

    private var providerTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("模型配置")
                                .font(.system(size: 16, weight: .semibold))
                            Text("每个模型保存独立的模型名、接口地址和 API Key。勾选后会立即保存并切换。")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            beginEditingModel(draft.activeModelProfile)
                        } label: {
                            Label("修改当前", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                        Button {
                            beginAddingModel()
                        } label: {
                            Label("添加模型", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    VStack(spacing: 8) {
                        ForEach(draft.modelProfiles) { profile in
                            modelProfileRow(profile)
                        }
                    }

                    Text("当前模型：\(draft.model)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
        }
        .sheet(isPresented: $isAddingModel) {
            ModelProfileEditorSheet(
                title: editingModelProfileID == nil ? "添加模型" : "修改模型",
                message: editingModelProfileID == nil
                    ? "保存模型名、接口地址和 API Key，之后可以在列表中快速切换。"
                    : "修改当前模型的名称、接口地址或 API Key，保存后会立即生效。",
                profile: $newModelProfile,
                onCancel: {
                    isAddingModel = false
                },
                onSave: {
                    saveModelProfile()
                }
            )
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ClipWise")
                .font(.system(size: 22, weight: .bold))
            Text("macOS 原生 Swift/AppKit/SwiftUI 版本。")
            Text("版本：0.1.0")
            Text("中文名：截图智读助手")
            Text("开发者：@Pilot.Phil")
            Text("邮箱：wenbodong@sjtu.edu.cn")
                .textSelection(.enabled)
            Text("设置文件：~/Library/Application Support/ClipWise/settings.json")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("macOS 如需全局快捷键，请授予运行终端或 Xcode “辅助功能”权限；截图失败时请检查“屏幕录制”权限。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
    }

    private var customTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("功能按钮")
                                .font(.system(size: 16, weight: .semibold))
                            Text("这些 AI 功能会显示在截图结果窗口右上角。内置功能和自定义功能会用竖线分隔。")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            beginAddingAction()
                        } label: {
                            Label("新增功能", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    VStack(spacing: 8) {
                        ForEach(draft.actionProfiles) { profile in
                            actionProfileRow(profile)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
        }
        .sheet(isPresented: $isEditingAction) {
            ActionProfileEditorSheet(
                title: editingActionProfileID == nil ? "新增功能" : "修改功能",
                profile: $actionDraft,
                onCancel: {
                    isEditingAction = false
                    editingActionProfileID = nil
                },
                onSave: {
                    saveActionProfile()
                }
            )
        }
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            draft.saveDirectory = url.path
        }
    }

    private func modifierToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlColor))
            )
        }
        .buttonStyle(.plain)
    }

    private func modelProfileRow(_ profile: ModelProfile) -> some View {
        let isActive = draft.activeModelProfileID == profile.id
        return HStack(spacing: 10) {
            Button {
                selectModel(profile)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.modelName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(profile.baseURL)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(profile.apiKey.isEmpty ? "API Key：空" : "API Key：已设置")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isActive {
                Button {
                    beginEditingModel(profile)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("修改当前模型")
            }

            Button {
                removeModel(profile)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(draft.modelProfiles.count <= 1)
            .help("删除模型")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlColor))
        )
    }

    private func beginAddingModel() {
        let active = draft.activeModelProfile
        editingModelProfileID = nil
        newModelProfile = ModelProfile(modelName: "", baseURL: active.baseURL, apiKey: active.apiKey)
        isAddingModel = true
    }

    private func beginEditingModel(_ profile: ModelProfile) {
        editingModelProfileID = profile.id
        newModelProfile = profile
        isAddingModel = true
    }

    private func saveModelProfile() {
        var profile = newModelProfile
        profile.modelName = profile.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.baseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.apiKey = profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profile.modelName.isEmpty, !profile.baseURL.isEmpty else { return }

        if let editingModelProfileID,
           let index = draft.modelProfiles.firstIndex(where: { $0.id == editingModelProfileID }) {
            profile.id = editingModelProfileID
            draft.modelProfiles[index] = profile
        } else if let index = draft.modelProfiles.firstIndex(where: {
            $0.modelName == profile.modelName && $0.baseURL == profile.baseURL
        }) {
            profile.id = draft.modelProfiles[index].id
            draft.modelProfiles[index] = profile
        } else {
            draft.modelProfiles.append(profile)
        }
        isAddingModel = false
        editingModelProfileID = nil
        selectModel(profile, persist: false)
        onSaveSettings(draft)
    }

    private func selectModel(_ profile: ModelProfile, persist: Bool = true) {
        draft.activeModelProfileID = profile.id
        draft.model = profile.modelName
        draft.baseURL = profile.baseURL
        draft.apiKey = profile.apiKey
        draft.modelOptions = draft.modelProfiles.map(\.modelName)
        if persist {
            onSaveSettings(draft)
        }
    }

    private func removeModel(_ profile: ModelProfile) {
        draft.modelProfiles.removeAll { $0.id == profile.id }
        if draft.modelProfiles.isEmpty {
            draft.modelProfiles = AppSettings().modelProfiles
        }
        if draft.activeModelProfileID == profile.id {
            selectModel(draft.modelProfiles[0], persist: false)
        }
        draft.modelOptions = draft.modelProfiles.map(\.modelName)
        onSaveSettings(draft)
    }

    private func actionProfileRow(_ profile: AIActionProfile) -> some View {
        HStack(spacing: 10) {
            ActionIconView(profile: profile, size: 18)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(profile.isBuiltIn ? "内置" : "自定义")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: .controlColor))
                        )
                }
                Text(profile.prompt)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                beginEditingAction(profile)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("修改功能")

            Button {
                confirmAndRemoveAction(profile)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("删除功能")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlColor))
        )
    }

    private func beginAddingAction() {
        editingActionProfileID = nil
        actionDraft = AIActionProfile(
            name: "自定义功能",
            systemImage: "sparkles",
            prompt: "请识别图片中的文字内容，并按照我的要求输出结果。"
        )
        isEditingAction = true
    }

    private func beginEditingAction(_ profile: AIActionProfile) {
        editingActionProfileID = profile.id
        actionDraft = profile
        isEditingAction = true
    }

    private func saveActionProfile() {
        var profile = actionDraft
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.systemImage = profile.systemImage.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.customIconPNGBase64 = profile.customIconPNGBase64?.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.prompt = profile.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !profile.name.isEmpty, !profile.prompt.isEmpty else { return }
        if profile.systemImage.isEmpty {
            profile.systemImage = "sparkles"
        }

        if let editingActionProfileID,
           let index = draft.actionProfiles.firstIndex(where: { $0.id == editingActionProfileID }) {
            profile.id = editingActionProfileID
            profile.isBuiltIn = draft.actionProfiles[index].isBuiltIn
            draft.actionProfiles[index] = profile
        } else {
            profile.id = UUID().uuidString
            profile.isBuiltIn = false
            draft.actionProfiles.append(profile)
        }

        isEditingAction = false
        editingActionProfileID = nil
        onSaveSettings(draft)
    }

    private func confirmAndRemoveAction(_ profile: AIActionProfile) {
        let alert = NSAlert()
        alert.messageText = "删除功能？"
        alert.informativeText = "确定要删除“\(profile.name)”吗？删除后截图结果窗口右上角将不再显示这个按钮。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        draft.actionProfiles.removeAll { $0.id == profile.id }
        onSaveSettings(draft)
    }
}

private struct ModelProfileEditorSheet: View {
    let title: String
    let message: String
    @Binding var profile: ModelProfile
    let onCancel: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !profile.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("模型名", text: $profile.modelName)
                TextField("URL", text: $profile.baseURL)
                SecureField("API Key，可留空", text: $profile.apiKey)
            }

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                Button("保存") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(18)
        .frame(width: 420)
    }
}

private struct ActionProfileEditorSheet: View {
    let title: String
    @Binding var profile: AIActionProfile
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var hoveredIcon: String?

    private let builtInIcons = [
        "1.circle",
        "2.circle",
        "3.circle",
        "4.circle",
        "5.circle",
        "6.circle",
        "7.circle",
        "8.circle",
        "9.circle",
        "1.square",
        "2.square",
        "3.square",
        "4.square",
        "5.square",
        "6.square",
        "7.square",
        "8.square",
        "9.square",
        "globe",
        "text.badge.checkmark",
        "doc.text",
        "sparkles",
        "wand.and.stars",
        "character.book.closed",
        "text.magnifyingglass",
        "doc.plaintext",
        "list.bullet.rectangle",
        "quote.bubble",
        "text.justify",
        "brain.head.profile",
        "doc.on.doc",
        "square.and.arrow.down",
        "pencil.and.outline",
        "lightbulb",
        "checklist",
        "captions.bubble",
    ]

    private var canSave: Bool {
        !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profile.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text("选择一个内置图标或上传按钮图片，提示词会随截图一起发送给当前模型。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("名称")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                TextField("名称", text: $profile.name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("图标")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ActionIconView(profile: profile, size: 20)
                            .frame(width: 28, height: 28)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(nsColor: .controlColor))
                            )
                    }

                    Text("内置图标")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 11), spacing: 6) {
                        ForEach(builtInIcons, id: \.self) { icon in
                            Button {
                                profile.systemImage = icon
                                profile.customIconPNGBase64 = nil
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(icon == profile.systemImage && profile.customIconPNGBase64 == nil ? Color.accentColor : Color.primary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(hoveredIcon == icon ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(
                                                hoveredIcon == icon || (icon == profile.systemImage && profile.customIconPNGBase64 == nil)
                                                    ? Color.accentColor
                                                    : Color(nsColor: .separatorColor),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(icon)
                            .onHover { hovering in
                                hoveredIcon = hovering ? icon : nil
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button("上传按钮图片") { uploadCustomIcon() }
                        if profile.customIconPNGBase64 != nil {
                            Button("移除上传图片") {
                                profile.customIconPNGBase64 = nil
                            }
                        }
                        Spacer()
                        Text("支持 PNG、JPEG、WebP")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("提示词")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $profile.prompt)
                        .font(.system(size: 13))
                        .frame(minHeight: 140)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
            }

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                Button("保存") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private func uploadCustomIcon() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .webP, .image]
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else {
            return
        }
        profile.customIconPNGBase64 = image.clipWisePNGData()?.base64EncodedString()
    }
}

private struct ActionIconView: View {
    let profile: AIActionProfile
    let size: CGFloat

    var body: some View {
        if let image = profile.clipWiseCustomIcon {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: profile.systemImage.isEmpty ? "sparkles" : profile.systemImage)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
    }
}

private extension AIActionProfile {
    var clipWiseCustomIcon: NSImage? {
        guard let customIconPNGBase64,
              let data = Data(base64Encoded: customIconPNGBase64),
              let image = NSImage(data: data)
        else {
            return nil
        }
        return image
    }
}

private extension NSImage {
    func clipWisePNGData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
