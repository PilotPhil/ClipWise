import AppKit

final class ResultWindowController: NSWindowController, NSToolbarDelegate {
    var onAIAction: ((AIActionProfile) -> Void)?
    var onUtilityAction: ((ResultUtilityAction) -> Void)?

    private let capture: CaptureResult
    private let actionProfiles: [AIActionProfile]
    private let resultPanelHeight: Int
    private let imageView = NSImageView()
    private let textView = NSTextView()
    private var toolbarActionsByID: [NSToolbarItem.Identifier: ResultToolbarAction] = [:]
    private var latestResult = ""
    private var isPinned = false
    private var pinButton: NSButton?

    init(capture: CaptureResult, actionProfiles: [AIActionProfile], resultPanelHeight: Int) {
        self.capture = capture
        self.actionProfiles = actionProfiles
        self.resultPanelHeight = resultPanelHeight
        let windowWidth = Self.preferredWindowWidth(for: capture, actionProfiles: actionProfiles)
        let size = NSSize(
            width: windowWidth,
            height: max(420, min(760, capture.image.size.height + 260))
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipWise - 截图智读助手"
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: min(windowWidth, Self.maximumWindowWidth()), height: 420)
        super.init(window: window)
        buildContent()
        installToolbar()
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func preferredWindowWidth(for capture: CaptureResult, actionProfiles: [AIActionProfile]) -> CGFloat {
        let builtInCount = actionProfiles.filter(\.isBuiltIn).count
        let customCount = actionProfiles.count - builtInCount
        let separatorCount = 1 + (customCount > 0 ? 1 : 0)
        let toolbarWidth = 260 + CGFloat(actionProfiles.count + ResultUtilityAction.toolbarActions.count) * 32 + CGFloat(separatorCount) * 8
        let contentWidth = max(640, min(1000, capture.image.size.width))
        return min(maximumWindowWidth(), max(contentWidth, toolbarWidth))
    }

    private static func maximumWindowWidth() -> CGFloat {
        if let visibleWidth = NSScreen.main?.visibleFrame.width {
            return max(760, visibleWidth * 0.92)
        }
        return 1400
    }

    func showResult(_ text: String) {
        latestResult = text
        textView.string = text
    }

    func copyLatestResult() {
        guard !latestResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latestResult, forType: .string)
    }

    func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "ClipWise_\(Int(Date().timeIntervalSince1970)).png"
        if panel.runModal() == .OK, let url = panel.url {
            try? capture.pngData.write(to: url)
        }
    }

    private func buildContent() {
        guard let window else { return }

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        imageView.image = capture.image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let imageContainer = NSView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.addSubview(imageView)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.string = "AI 结果会显示在这里"
        scroll.documentView = textView

        let imageSection = sectionView(title: "截图内容", content: imageContainer)
        let resultSection = sectionView(title: "AI 返回结果", content: scroll)

        let stack = NSStackView(views: [imageSection, resultSection])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(stack)
        window.contentView = content

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),

            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -12),
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: 12),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: -12),

            imageSection.heightAnchor.constraint(greaterThanOrEqualToConstant: 210),
            resultSection.heightAnchor.constraint(equalToConstant: CGFloat(resultPanelHeight)),
        ])
    }

    private func sectionView(title: String, content: NSView) -> NSView {
        let section = NSView()
        section.translatesAutoresizingMaskIntoConstraints = false
        section.wantsLayer = true
        section.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        section.layer?.borderColor = NSColor.separatorColor.cgColor
        section.layer?.borderWidth = 1
        section.layer?.cornerRadius = 8

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        content.translatesAutoresizingMaskIntoConstraints = false
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        content.layer?.cornerRadius = 6
        content.layer?.borderColor = NSColor.separatorColor.cgColor
        content.layer?.borderWidth = 1

        section.addSubview(titleLabel)
        section.addSubview(content)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: section.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: section.topAnchor, constant: 8),

            content.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 10),
            content.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -10),
            content.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),
            content.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: -10),
        ])
        return section
    }

    private func installToolbar() {
        guard let window else { return }
        let toolbar = NSToolbar(identifier: "ClipWiseResultToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .small
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let builtInActions = actionProfiles.filter(\.isBuiltIn)
        let customActions = actionProfiles.filter { !$0.isBuiltIn }

        toolbarActionsByID = [:]
        for action in builtInActions + customActions {
            toolbarActionsByID[action.toolbarIdentifier] = .ai(action)
        }
        for action in ResultUtilityAction.toolbarActions {
            toolbarActionsByID[action.toolbarIdentifier] = .utility(action)
        }
        return [.flexibleSpace, .clipWiseTitle, .flexibleSpace, .clipWiseActionGroup]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == .clipWiseTitle {
            let item = NSToolbarItem(itemIdentifier: .clipWiseTitle)
            let label = NSTextField(labelWithString: "ClipWise - 截图智读助手")
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .labelColor
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            let wrapper = NSView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
                wrapper.heightAnchor.constraint(equalToConstant: 28),
            ])
            item.view = wrapper
            item.visibilityPriority = .high
            return item
        }
        guard itemIdentifier == .clipWiseActionGroup else {
            return nil
        }
        let item = NSToolbarItem(itemIdentifier: .clipWiseActionGroup)
        item.view = toolbarActionGroupView()
        item.visibilityPriority = .high
        return item
    }

    private func toolbarActionGroupView() -> NSView {
        let builtInActions = actionProfiles.filter(\.isBuiltIn)
        let customActions = actionProfiles.filter { !$0.isBuiltIn }
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        for action in builtInActions {
            stack.addArrangedSubview(toolbarButton(for: .ai(action), identifier: action.toolbarIdentifier))
        }
        if !customActions.isEmpty {
            stack.addArrangedSubview(separatorView())
            for action in customActions {
                stack.addArrangedSubview(toolbarButton(for: .ai(action), identifier: action.toolbarIdentifier))
            }
        }
        stack.addArrangedSubview(separatorView())
        for action in ResultUtilityAction.toolbarActions {
            stack.addArrangedSubview(toolbarButton(for: .utility(action), identifier: action.toolbarIdentifier))
        }

        let pinBtn = pinToggleButton()
        pinButton = pinBtn
        stack.addArrangedSubview(pinBtn)

        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            wrapper.heightAnchor.constraint(equalToConstant: 28),
        ])
        return wrapper
    }

    private func toolbarButton(for action: ResultToolbarAction, identifier: NSToolbarItem.Identifier) -> NSButton {
        let button = NSButton(
            image: action.image,
            target: self,
            action: #selector(toolbarButtonPressed(_:))
        )
        button.identifier = NSUserInterfaceItemIdentifier(identifier.rawValue)
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = action.tooltip
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 28),
        ])
        return button
    }

    private func separatorView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        let line = NSView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.separatorColor.cgColor
        view.addSubview(line)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 4),
            view.heightAnchor.constraint(equalToConstant: 24),
            line.widthAnchor.constraint(equalToConstant: 1),
            line.heightAnchor.constraint(equalToConstant: 18),
            line.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            line.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }

    private func pinToggleButton() -> NSButton {
        let imageName = isPinned ? "pin.fill" : "pin"
        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "窗口置顶")
        let button = NSButton(
            image: image ?? NSImage(),
            target: self,
            action: #selector(togglePin(_:))
        )
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = isPinned ? "取消置顶" : "窗口置顶"
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 28),
        ])
        return button
    }

    @objc private func togglePin(_ sender: NSButton) {
        isPinned.toggle()
        let imageName = isPinned ? "pin.fill" : "pin"
        sender.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "窗口置顶")
        sender.toolTip = isPinned ? "取消置顶" : "窗口置顶"
        window?.level = isPinned ? .floating : .normal
    }

    @objc private func toolbarButtonPressed(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue else { return }
        handleToolbarItem(identifier: NSToolbarItem.Identifier(rawValue))
    }

    @objc private func toolbarItemPressed(_ sender: NSToolbarItem) {
        handleToolbarItem(identifier: sender.itemIdentifier)
    }

    private func handleToolbarItem(identifier: NSToolbarItem.Identifier) {
        guard let action = toolbarActionsByID[identifier] else {
            return
        }
        switch action {
        case .ai(let profile):
            onAIAction?(profile)
        case .utility(let utility):
            onUtilityAction?(utility)
        }
    }
}

private enum ResultToolbarAction {
    case ai(AIActionProfile)
    case utility(ResultUtilityAction)

    var label: String {
        switch self {
        case .ai(let profile):
            return profile.name
        case .utility(let action):
            return action.tooltip
        }
    }

    var tooltip: String {
        switch self {
        case .ai(let profile):
            return profile.name
        case .utility(let action):
            return action.tooltip
        }
    }

    var systemImage: String {
        switch self {
        case .ai(let profile):
            return profile.systemImage
        case .utility(let action):
            return action.systemImage
        }
    }

    var image: NSImage {
        switch self {
        case .ai(let profile):
            return profile.toolbarIcon
        case .utility(let action):
            return NSImage(systemSymbolName: action.systemImage, accessibilityDescription: action.tooltip)
                ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: action.tooltip)
                ?? NSImage()
        }
    }
}

private extension AIActionProfile {
    var toolbarIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("ClipWise.ai.\(id)")
    }

    var toolbarIcon: NSImage {
        if let customIconPNGBase64,
           let data = Data(base64Encoded: customIconPNGBase64),
           let image = NSImage(data: data) {
            return image
        }
        return NSImage(systemSymbolName: systemImage, accessibilityDescription: name)
            ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: name)
            ?? NSImage()
    }
}

private extension NSToolbarItem.Identifier {
    static let clipWiseTitle = NSToolbarItem.Identifier("ClipWise.title")
    static let clipWiseActionGroup = NSToolbarItem.Identifier("ClipWise.actionGroup")
    static let clipWiseAICustomSeparator = NSToolbarItem.Identifier("ClipWise.separator.aiCustom")
    static let clipWiseUtilitySeparator = NSToolbarItem.Identifier("ClipWise.separator.utility")
}

private extension ResultUtilityAction {
    static var toolbarActions: [ResultUtilityAction] {
        [.copy, .save]
    }

    var toolbarIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("ClipWise.utility.\(rawValue)")
    }
}
