import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var hotkeyMonitor: HotkeyMonitor?
    private let settingsStore = SettingsStore()
    private lazy var screenshotController = ScreenshotController()
    private lazy var openAIClient = OpenAICompatibleClient()
    private var resultWindowController: ResultWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        installStatusItem()
        showMainWindow()
        installHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor?.stop()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "ClipWise")
        appMenu.addItem(
            NSMenuItem(
                title: "退出 ClipWise",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.statusBarIcon()
                ?? NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "ClipWise")
                ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: "ClipWise")
            button.image?.isTemplate = true
            button.toolTip = "ClipWise 截图智读助手"
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "显示主界面",
                action: #selector(showMainWindowFromStatusItem),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "退出",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: ""
            )
        )
        item.menu = menu
        statusItem = item
    }

    private static func statusBarIcon() -> NSImage? {
        Bundle.main.image(forResource: "StatusBarTemplate")
            ?? Bundle.module.image(forResource: "StatusBarTemplate")
    }

    @objc private func showMainWindowFromStatusItem() {
        showMainWindow()
    }

    private func showMainWindow() {
        let rootView = MainSettingsView(
            settings: settingsStore.settings,
            statusText: startupStatusText(),
            onStartCapture: { [weak self] in self?.startCapture() },
            onSaveSettings: { [weak self] newSettings in
                self?.settingsStore.save(newSettings)
                self?.installHotkey()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        let window = mainWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 410),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipWise - 截图智读助手"
        window.contentViewController = NSHostingController(rootView: rootView)
        if mainWindow == nil {
            window.center()
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    private func installHotkey() {
        hotkeyMonitor?.stop()
        hotkeyMonitor = HotkeyMonitor(settings: settingsStore.settings) { [weak self] in
            self?.startCapture()
        }
        hotkeyMonitor?.start()
    }

    private func startCapture() {
        screenshotController.startSelection { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let capture):
                self.showResultWindow(capture: capture)
            case .failure(let error):
                self.showError(error.localizedDescription)
            }
        }
    }

    private func showResultWindow(capture: CaptureResult) {
        let settings = settingsStore.settings
        let controller = ResultWindowController(
            capture: capture,
            actionProfiles: settings.actionProfiles,
            resultPanelHeight: settings.resultPanelHeight
        )
        controller.onAIAction = { [weak self, weak controller] action in
            guard let self, let controller else { return }
            self.handleAIAction(action, capture: capture, controller: controller)
        }
        controller.onUtilityAction = { [weak self, weak controller] action in
            guard let self, let controller else { return }
            self.handleUtilityAction(action, controller: controller)
        }
        resultWindowController = controller
        controller.showWindow(nil)
    }

    private func handleUtilityAction(_ action: ResultUtilityAction, controller: ResultWindowController) {
        switch action {
        case .copy:
            controller.copyLatestResult()
        case .save:
            controller.saveImage()
        }
    }

    private func handleAIAction(_ action: AIActionProfile, capture: CaptureResult, controller: ResultWindowController) {
        controller.showResult("正在执行“\(action.name)”，请稍候...")
        let settings = settingsStore.settings
        let imagePNG = capture.pngData
        Task { @MainActor in
            do {
                let text = try await OpenAICompatibleClient().process(action: action, imagePNG: imagePNG, settings: settings)
                controller.showResult(text)
            } catch {
                controller.showResult("处理失败：\(error.localizedDescription)")
            }
        }
    }

    private func startupStatusText() -> String {
        let settings = settingsStore.settings
        var lines = [
            "ClipWise 截图智读助手已启动。",
            "",
            "快捷键：\(settings.captureHotkey.displayText)",
            "也可以点击本窗口的“开始截图”。",
            "AI 接口：\(settings.baseURL)",
            "模型：\(settings.model)",
        ]
        lines.append("")
        lines.append("提示：")
        lines.append("- macOS 首次运行可能需要授予“屏幕录制”和“辅助功能”权限。")
        return lines.joined(separator: "\n")
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "ClipWise"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
