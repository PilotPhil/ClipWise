import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var hotkeyMonitor: HotkeyMonitor?
    private let settingsStore = SettingsStore()
    private lazy var screenshotController = ScreenshotController()
    private lazy var openAIClient = OpenAICompatibleClient()
    private var resultWindowController: ResultWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        installStatusItem()
        showResultWindow(capture: nil)
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
                action: #selector(showResultWindowFromStatusItem),
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

    @objc private func showResultWindowFromStatusItem() {
        showResultWindow(capture: nil)
    }

    private func showSettingsWindow() {
        let rootView = MainSettingsView(
            settings: settingsStore.settings,
            onSaveSettings: { [weak self] newSettings in
                self?.settingsStore.save(newSettings)
                self?.installHotkey()
                self?.resultWindowController?.updateActionProfiles(newSettings.actionProfiles)
                self?.resultWindowController?.setHideWindowsDuringCapture(newSettings.hideWindowsDuringCapture)
            }
        )

        let window = settingsWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 410),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipWise 设置"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)
        if settingsWindow == nil {
            window.center()
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private func installHotkey() {
        hotkeyMonitor?.stop()
        hotkeyMonitor = HotkeyMonitor(settings: settingsStore.settings) { [weak self] in
            self?.startCapture()
        }
        hotkeyMonitor?.start()
    }

    private func startCapture() {
        let windowsToRestore = hideWindowsForCaptureIfNeeded()
        let delay: DispatchTimeInterval = windowsToRestore.isEmpty ? .milliseconds(0) : .milliseconds(160)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.startCaptureSelection(restoring: windowsToRestore)
        }
    }

    private func startCaptureSelection(restoring windowsToRestore: [NSWindow]) {
        screenshotController.startSelection { [weak self] result in
            guard let self else { return }
            self.restoreWindowsAfterCapture(windowsToRestore)
            switch result {
            case .success(let capture):
                self.showResultWindow(capture: capture)
            case .failure(let error):
                self.showError(error.localizedDescription)
            }
        }
    }

    private func hideWindowsForCaptureIfNeeded() -> [NSWindow] {
        guard settingsStore.settings.hideWindowsDuringCapture else { return [] }
        let windows = NSApplication.shared.windows.filter { window in
            window.isVisible && !window.isMiniaturized
        }
        windows.forEach { $0.orderOut(nil) }
        return windows
    }

    private func restoreWindowsAfterCapture(_ windows: [NSWindow]) {
        guard !windows.isEmpty else { return }
        windows.forEach { window in
            if !window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func showResultWindow(capture: CaptureResult?) {
        let settings = settingsStore.settings
        let controller: ResultWindowController
        if let existing = resultWindowController {
            controller = existing
            controller.updateActionProfiles(settings.actionProfiles)
            controller.setHideWindowsDuringCapture(settings.hideWindowsDuringCapture)
            if let capture {
                controller.updateCapture(capture)
            }
        } else {
            controller = ResultWindowController(
                capture: capture,
                actionProfiles: settings.actionProfiles,
                resultPanelHeight: settings.resultPanelHeight,
                hideWindowsDuringCapture: settings.hideWindowsDuringCapture
            )
            controller.onAIAction = { [weak self, weak controller] action in
                guard let self, let controller else { return }
                self.handleAIAction(action, controller: controller)
            }
            controller.onRecapture = { [weak self] in
                self?.startCapture()
            }
            controller.onShowSettings = { [weak self] in
                self?.showSettingsWindow()
            }
            controller.onHideWindowsDuringCaptureChanged = { [weak self] value in
                guard let self else { return }
                var settings = self.settingsStore.settings
                settings.hideWindowsDuringCapture = value
                self.settingsStore.save(settings)
            }
            resultWindowController = controller
        }
        if let window = controller.window, window.isMiniaturized {
            window.deminiaturize(nil)
        }
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func handleAIAction(_ action: AIActionProfile, controller: ResultWindowController) {
        guard let capture = controller.currentCapture else {
            controller.showResult("请先截图，然后再执行“\(action.name)”。")
            return
        }
        controller.showResult("正在执行“\(action.name)”，请稍候...")
        controller.setProcessing(true)
        let settings = settingsStore.settings
        let imagePNG = capture.pngData
        Task { @MainActor in
            defer {
                controller.setProcessing(false)
            }
            do {
                let text = try await OpenAICompatibleClient().process(action: action, imagePNG: imagePNG, settings: settings)
                controller.showResult(text)
            } catch {
                controller.showResult("处理失败：\(error.localizedDescription)")
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "ClipWise"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
