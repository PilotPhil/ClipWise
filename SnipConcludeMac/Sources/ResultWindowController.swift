import AppKit

final class ResultWindowController: NSWindowController {
    var onAIAction: ((AIActionProfile) -> Void)?
    var onRecapture: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onHideWindowsDuringCaptureChanged: ((Bool) -> Void)?

    private var capture: CaptureResult?
    private var actionProfiles: [AIActionProfile]
    private let resultPanelHeight: Int
    private var hideWindowsDuringCapture: Bool

    private let backgroundView = RainbowWaveBackgroundView()
    private let imageView = ZoomableCaptureView()
    private let emptyCaptureView = NSView()
    private let textView = NSTextView()
    private let zoomLabel = NSTextField(labelWithString: "100%")
    private let hideDuringCaptureCheckbox = NSButton(checkboxWithTitle: "截图时隐藏窗口", target: nil, action: nil)
    private var tabBarStack: NSStackView?
    private var tabBarFiller: NSView?
    private var actionTabButtons: [String: ResultTabButton] = [:]
    private var latestResult = ""
    private var activeActionID: String?
    private var imageZoom: CGFloat = 1.0
    private var isPinned = false
    private weak var pinButton: NSButton?
    private weak var rootContentView: NSView?
    private weak var captureCanvasPanel: NSView?
    private weak var resultCardPanel: NSView?
    private weak var resultScrollView: NSScrollView?
    private var titlebarAccessoryController: NSTitlebarAccessoryViewController?

    var currentCapture: CaptureResult? {
        capture
    }

    init(
        capture: CaptureResult?,
        actionProfiles: [AIActionProfile],
        resultPanelHeight: Int,
        hideWindowsDuringCapture: Bool
    ) {
        self.capture = capture
        self.actionProfiles = actionProfiles
        self.resultPanelHeight = resultPanelHeight
        self.hideWindowsDuringCapture = hideWindowsDuringCapture

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipWise  截图智读助手"
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 520)

        super.init(window: window)
        activeActionID = actionProfiles.first?.id
        buildContent()
        installTitlebarAccessory()
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showResult(_ text: String) {
        latestResult = text
        textView.string = text
        textView.textColor = .labelColor
    }

    func setProcessing(_ isProcessing: Bool) {
        guard let rootContentView else { return }
        if isProcessing {
            rootContentView.layer?.backgroundColor = NSColor.clear.cgColor
            captureCanvasPanel?.layer?.backgroundColor = ClipWiseColors.canvasBackground.withAlphaComponent(0.70).cgColor
            resultCardPanel?.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.82).cgColor
            resultScrollView?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.82)
            textView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.82)
            backgroundView.isHidden = false
            backgroundView.startAnimating()
        } else {
            backgroundView.stopAnimating()
            backgroundView.isHidden = true
            rootContentView.layer?.backgroundColor = ClipWiseColors.pageBackground.cgColor
            captureCanvasPanel?.layer?.backgroundColor = ClipWiseColors.canvasBackground.cgColor
            resultCardPanel?.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
            resultScrollView?.backgroundColor = .textBackgroundColor
            textView.backgroundColor = .textBackgroundColor
        }
    }

    func copyLatestResult() {
        guard !latestResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latestResult, forType: .string)
    }

    func saveImage() {
        guard let capture else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "ClipWise_\(Int(Date().timeIntervalSince1970)).png"
        if panel.runModal() == .OK, let url = panel.url {
            try? capture.pngData.write(to: url)
        }
    }

    func updateCapture(_ capture: CaptureResult) {
        self.capture = capture
        imageView.image = capture.image
        imageView.isHidden = false
        emptyCaptureView.isHidden = true
        clearResultPressed()
        DispatchQueue.main.async { [weak self] in
            self?.fitImageToWindow()
        }
    }

    func updateActionProfiles(_ profiles: [AIActionProfile]) {
        actionProfiles = profiles
        if let activeActionID, !profiles.contains(where: { $0.id == activeActionID }) {
            self.activeActionID = profiles.first?.id
        } else if activeActionID == nil {
            activeActionID = profiles.first?.id
        }
        rebuildResultTabs()
    }

    func setHideWindowsDuringCapture(_ value: Bool) {
        hideWindowsDuringCapture = value
        hideDuringCaptureCheckbox.state = value ? .on : .off
    }

    private func buildContent() {
        guard let window else { return }

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = ClipWiseColors.pageBackground.cgColor
        rootContentView = content
        window.contentView = content

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.isHidden = true
        content.addSubview(backgroundView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let captureHeader = sectionHeader(
            title: "截图内容",
            trailingView: captureControlsView()
        )
        let captureCanvas = captureCanvasView()
        let resultHeader = sectionHeader(
            title: "智读结果",
            trailingView: resultControlsView()
        )
        let resultCard = resultCardView()
        let footer = footerView()

        stack.addArrangedSubview(captureHeader)
        stack.addArrangedSubview(captureCanvas)
        stack.addArrangedSubview(resultHeader)
        stack.addArrangedSubview(resultCard)
        stack.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: content.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),

            captureHeader.widthAnchor.constraint(equalTo: stack.widthAnchor),
            captureCanvas.widthAnchor.constraint(equalTo: stack.widthAnchor),
            resultHeader.widthAnchor.constraint(equalTo: stack.widthAnchor),
            resultCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),

            captureCanvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 170),
            captureCanvas.heightAnchor.constraint(lessThanOrEqualToConstant: 280),
            resultCard.heightAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(max(200, min(resultPanelHeight, 260)))),
        ])
    }

    private func installTitlebarAccessory() {
        guard let window else { return }

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let settingsButton = titlebarButton(systemImage: "gearshape", tooltip: "设置")
        settingsButton.target = self
        settingsButton.action = #selector(showSettingsPressed)

        let pin = titlebarButton(systemImage: "pin", tooltip: "窗口置顶")
        pin.target = self
        pin.action = #selector(togglePin(_:))
        pinButton = pin

        stack.addArrangedSubview(settingsButton)
        stack.addArrangedSubview(pin)

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 74, height: 40))
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            host.widthAnchor.constraint(equalToConstant: 74),
            host.heightAnchor.constraint(equalToConstant: 40),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: host.centerYAnchor),
        ])

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        accessory.view = host
        titlebarAccessoryController = accessory
        window.addTitlebarAccessoryViewController(accessory)
    }

    private func titlebarButton(systemImage: String, tooltip: String) -> ResultIconButton {
        let button = ResultIconButton(
            image: NSImage(systemSymbolName: systemImage, accessibilityDescription: tooltip) ?? NSImage(),
            target: nil,
            action: nil,
            size: 28,
            hoverColor: ClipWiseColors.hoverBlue
        )
        button.toolTip = tooltip
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    private func sectionHeader(title: String, trailingView: NSView) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .labelColor

        trailingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        view.addSubview(trailingView)

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            trailingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trailingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            trailingView.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 12),
        ])
        return view
    }

    private func captureControlsView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5

        hideDuringCaptureCheckbox.font = .systemFont(ofSize: 12)
        hideDuringCaptureCheckbox.state = hideWindowsDuringCapture ? .on : .off
        hideDuringCaptureCheckbox.target = self
        hideDuringCaptureCheckbox.action = #selector(hideDuringCaptureChanged(_:))
        hideDuringCaptureCheckbox.toolTip = "截图时临时隐藏 ClipWise 窗口，完成选择后自动恢复"
        stack.addArrangedSubview(hideDuringCaptureCheckbox)

        stack.addArrangedSubview(
            pillButton(title: "重新截图", systemImage: "camera", action: #selector(recapturePressed))
        )
        stack.addArrangedSubview(
            pillButton(title: "适应窗口", systemImage: "arrow.up.left.and.arrow.down.right", action: #selector(fitImageToWindow))
        )

        zoomLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        zoomLabel.textColor = .secondaryLabelColor
        zoomLabel.alignment = .center
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        let zoomBox = roundedBox(containing: zoomLabel, width: 56, height: 26)
        stack.addArrangedSubview(zoomBox)

        stack.addArrangedSubview(iconButton(systemImage: "magnifyingglass.circle", tooltip: "放大", action: #selector(zoomIn)))
        stack.addArrangedSubview(iconButton(systemImage: "minus.magnifyingglass", tooltip: "缩小", action: #selector(zoomOut)))
        return stack
    }

    private func resultControlsView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5

        stack.addArrangedSubview(
            pillButton(title: "复制图片", systemImage: "photo.on.rectangle", action: #selector(copyImagePressed))
        )
        stack.addArrangedSubview(
            pillButton(title: "复制内容", systemImage: "doc.on.doc", action: #selector(copyResultPressed))
        )
        stack.addArrangedSubview(
            pillButton(title: "导出", systemImage: "square.and.arrow.down", action: #selector(exportResultPressed))
        )
        let clear = pillButton(title: "清空", systemImage: "trash", action: #selector(clearResultPressed))
        clear.contentTintColor = .systemRed
        stack.addArrangedSubview(clear)
        return stack
    }

    private func captureCanvasView() -> NSView {
        let canvas = NSView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = ClipWiseColors.canvasBackground.cgColor
        canvas.layer?.borderColor = ClipWiseColors.border.cgColor
        canvas.layer?.borderWidth = 1
        canvas.layer?.cornerRadius = 8
        canvas.layer?.masksToBounds = true
        captureCanvasPanel = canvas

        imageView.image = capture?.image
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = capture == nil
        imageView.onZoomChanged = { [weak self] zoom in
            self?.imageZoom = zoom
            self?.updateZoomLabel()
        }
        canvas.addSubview(imageView)
        installEmptyCaptureView(in: canvas)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: canvas.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -10),
            imageView.topAnchor.constraint(equalTo: canvas.topAnchor, constant: 10),
            imageView.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -10),
        ])
        return canvas
    }

    private func installEmptyCaptureView(in canvas: NSView) {
        emptyCaptureView.translatesAutoresizingMaskIntoConstraints = false
        emptyCaptureView.isHidden = capture != nil

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "暂无截图内容")
        icon.contentTintColor = .tertiaryLabelColor

        let title = NSTextField(labelWithString: "暂无截图内容")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .secondaryLabelColor

        let subtitle = NSTextField(labelWithString: "点击“重新截图”或使用快捷键开始")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .tertiaryLabelColor

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)

        emptyCaptureView.addSubview(stack)
        canvas.addSubview(emptyCaptureView)

        NSLayoutConstraint.activate([
            emptyCaptureView.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            emptyCaptureView.centerYAnchor.constraint(equalTo: canvas.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: emptyCaptureView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: emptyCaptureView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: emptyCaptureView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: emptyCaptureView.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func resultCardView() -> NSView {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        card.layer?.borderColor = ClipWiseColors.border.cgColor
        card.layer?.borderWidth = 1
        card.layer?.cornerRadius = 7
        card.layer?.masksToBounds = true
        resultCardPanel = card

        let tabBar = resultTabsView()
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = ClipWiseColors.border.cgColor

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        resultScrollView = scroll

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .secondaryLabelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 18, height: 16)
        textView.string = "暂无识别结果"
        scroll.documentView = textView

        card.addSubview(tabBar)
        card.addSubview(separator)
        card.addSubview(scroll)

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: card.topAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 44),

            separator.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            separator.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func resultTabsView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        tabBarStack = stack
        rebuildResultTabs(in: stack)
        return stack
    }

    private func rebuildResultTabs() {
        guard let tabBarStack else { return }
        rebuildResultTabs(in: tabBarStack)
    }

    private func rebuildResultTabs(in stack: NSStackView) {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        actionTabButtons = [:]
        for profile in actionProfiles {
            let button = ResultTabButton(profile: profile, isActive: profile.id == activeActionID)
            button.target = self
            button.action = #selector(actionTabPressed(_:))
            button.identifier = NSUserInterfaceItemIdentifier(profile.id)
            button.toolTip = profile.name
            actionTabButtons[profile.id] = button
            stack.addArrangedSubview(button)
        }
        let filler = NSView()
        tabBarFiller = filler
        stack.addArrangedSubview(filler)
    }

    private func footerView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let status = NSTextField(labelWithString: "○  就绪")
        status.translatesAutoresizingMaskIntoConstraints = false
        status.font = .systemFont(ofSize: 12)
        status.textColor = .tertiaryLabelColor

        let version = NSTextField(labelWithString: "ClipWise v1.0.0")
        version.translatesAutoresizingMaskIntoConstraints = false
        version.font = .systemFont(ofSize: 12)
        version.textColor = .tertiaryLabelColor

        view.addSubview(status)
        view.addSubview(version)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 18),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            status.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            version.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            version.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }

    private func roundedBox(containing child: NSView, width: CGFloat, height: CGFloat) -> NSView {
        let box = NSView()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        box.layer?.borderColor = ClipWiseColors.border.cgColor
        box.layer?.borderWidth = 1
        box.layer?.cornerRadius = 5
        box.addSubview(child)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: width),
            box.heightAnchor.constraint(equalToConstant: height),
            child.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            child.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    private func pillButton(title: String, systemImage: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    private func iconButton(systemImage: String, tooltip: String, action: Selector) -> NSButton {
        let button = ResultIconButton(
            image: NSImage(systemSymbolName: systemImage, accessibilityDescription: tooltip) ?? NSImage(),
            target: self,
            action: action,
            size: 26,
            hoverColor: ClipWiseColors.hoverBlue
        )
        button.toolTip = tooltip
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    private func refreshTabs() {
        for (id, button) in actionTabButtons {
            button.isActive = id == activeActionID
        }
    }

    @objc private func actionTabPressed(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let action = actionProfiles.first(where: { $0.id == id })
        else { return }
        activeActionID = id
        refreshTabs()
        guard capture != nil else {
            showResult("请先截图，然后再执行“\(action.name)”。")
            return
        }
        onAIAction?(action)
    }

    @objc private func recapturePressed() {
        onRecapture?()
    }

    @objc private func hideDuringCaptureChanged(_ sender: NSButton) {
        hideWindowsDuringCapture = sender.state == .on
        onHideWindowsDuringCaptureChanged?(hideWindowsDuringCapture)
    }

    @objc private func fitImageToWindow() {
        imageView.fitToBounds()
    }

    @objc private func zoomIn() {
        imageView.zoomIn()
    }

    @objc private func zoomOut() {
        imageView.zoomOut()
    }

    @objc private func copyImagePressed() {
        guard let capture else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(capture.pngData, forType: .png)
        if let tiff = capture.image.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    @objc private func copyResultPressed() {
        copyLatestResult()
    }

    @objc private func exportResultPressed() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "ClipWise_Result_\(Int(Date().timeIntervalSince1970)).txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? latestResult.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @objc private func clearResultPressed() {
        latestResult = ""
        textView.string = "暂无识别结果"
        textView.textColor = .secondaryLabelColor
    }

    @objc private func togglePin(_ sender: NSButton) {
        isPinned.toggle()
        let imageName = isPinned ? "pin.fill" : "pin"
        sender.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "窗口置顶")
        sender.toolTip = isPinned ? "取消置顶" : "窗口置顶"
        window?.level = isPinned ? .floating : .normal
    }

    @objc private func showSettingsPressed() {
        onShowSettings?()
    }

    private func updateZoomLabel() {
        zoomLabel.stringValue = "\(Int((imageZoom * 100).rounded()))%"
    }
}

private final class ZoomableCaptureView: NSView {
    var image: NSImage? {
        didSet {
            offset = .zero
            needsFitOnLayout = true
            needsDisplay = true
        }
    }
    var onZoomChanged: ((CGFloat) -> Void)?

    private(set) var zoom: CGFloat = 1.0
    private var offset: CGPoint = .zero
    private var lastDragPoint: CGPoint?
    private var shouldStayFit = true
    private var needsFitOnLayout = true

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        if needsFitOnLayout || shouldStayFit {
            fitToBounds()
            needsFitOnLayout = false
        }
    }

    func fitToBounds() {
        guard let image, image.size.width > 0, image.size.height > 0, bounds.width > 0, bounds.height > 0 else {
            zoom = 1.0
            onZoomChanged?(zoom)
            return
        }
        let availableWidth = max(1, bounds.width - 24)
        let availableHeight = max(1, bounds.height - 24)
        zoom = min(availableWidth / image.size.width, availableHeight / image.size.height)
        offset = .zero
        shouldStayFit = true
        onZoomChanged?(zoom)
        needsDisplay = true
    }

    func zoomIn() {
        setZoom(zoom * 1.12)
    }

    func zoomOut() {
        setZoom(zoom / 1.12)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image else { return }

        NSGraphicsContext.current?.imageInterpolation = .high
        let drawSize = NSSize(width: image.size.width * zoom, height: image.size.height * zoom)
        let origin = CGPoint(
            x: bounds.midX - drawSize.width / 2 + offset.x,
            y: bounds.midY - drawSize.height / 2 + offset.y
        )
        image.draw(
            in: NSRect(origin: origin, size: drawSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastDragPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let lastDragPoint {
            offset.x += point.x - lastDragPoint.x
            offset.y += point.y - lastDragPoint.y
            shouldStayFit = false
            needsDisplay = true
        }
        lastDragPoint = point
    }

    override func mouseUp(with event: NSEvent) {
        lastDragPoint = nil
    }

    override func scrollWheel(with event: NSEvent) {
        offset.x += event.scrollingDeltaX
        offset.y += event.scrollingDeltaY
        shouldStayFit = false
        needsDisplay = true
    }

    override func magnify(with event: NSEvent) {
        setZoom(zoom * max(0.2, 1 + event.magnification))
    }

    private func setZoom(_ value: CGFloat) {
        let clamped = min(max(value, 0.05), 8.0)
        guard abs(clamped - zoom) > 0.0001 else { return }
        zoom = clamped
        shouldStayFit = false
        onZoomChanged?(zoom)
        needsDisplay = true
    }
}

private enum ClipWiseColors {
    static let pageBackground = NSColor(calibratedRed: 0.945, green: 0.960, blue: 0.980, alpha: 1)
    static let canvasBackground = NSColor(calibratedRed: 0.925, green: 0.940, blue: 0.965, alpha: 1)
    static let border = NSColor(calibratedRed: 0.840, green: 0.870, blue: 0.910, alpha: 1)
    static let hoverBlue = NSColor(calibratedRed: 0.875, green: 0.935, blue: 1.000, alpha: 1)
    static let accentBlue = NSColor(calibratedRed: 0.180, green: 0.470, blue: 0.980, alpha: 1)
}

private final class RainbowWaveBackgroundView: NSView {
    private var timer: Timer?
    private var phase: CGFloat = 0

    override var isFlipped: Bool { true }

    func startAnimating() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(animationTick), userInfo: nil, repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        needsDisplay = true
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        phase = 0
        needsDisplay = true
    }

    @objc private func animationTick() {
        phase += 0.035
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let baseColors = rainbowColors(alpha: 0.62)
        let gradient = NSGradient(colors: baseColors) ?? NSGradient(colors: [.systemBlue, .systemPink])!
        gradient.draw(in: bounds, angle: CGFloat(12 + sin(phase) * 10))

        NSColor.white.withAlphaComponent(0.22).setFill()
        bounds.fill(using: .sourceAtop)

        drawWave(
            amplitude: bounds.height * 0.055,
            baseline: bounds.height * 0.33,
            frequency: 1.7,
            speed: 1.2,
            color: NSColor.white.withAlphaComponent(0.24)
        )
        drawWave(
            amplitude: bounds.height * 0.075,
            baseline: bounds.height * 0.58,
            frequency: 1.25,
            speed: -0.9,
            color: NSColor(calibratedRed: 0.5, green: 0.85, blue: 1.0, alpha: 0.18)
        )
        drawWave(
            amplitude: bounds.height * 0.045,
            baseline: bounds.height * 0.78,
            frequency: 2.2,
            speed: 1.6,
            color: NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.95, alpha: 0.18)
        )
    }

    private func rainbowColors(alpha: CGFloat) -> [NSColor] {
        (0..<7).map { index in
            let hue = (CGFloat(index) / 7.0 + phase * 0.075).truncatingRemainder(dividingBy: 1)
            return NSColor(calibratedHue: hue, saturation: 0.58, brightness: 1.0, alpha: alpha)
        }
    }

    private func drawWave(
        amplitude: CGFloat,
        baseline: CGFloat,
        frequency: CGFloat,
        speed: CGFloat,
        color: NSColor
    ) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.line(to: CGPoint(x: bounds.minX, y: baseline))

        let width = max(bounds.width, 1)
        let step: CGFloat = 8
        var x: CGFloat = 0
        while x <= bounds.width + step {
            let progress = x / width
            let y = baseline + sin(progress * .pi * 2 * frequency + phase * speed * .pi * 2) * amplitude
            path.line(to: CGPoint(x: x, y: y))
            x += step
        }

        path.line(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.close()
        color.setFill()
        path.fill()
    }
}

private final class ResultIconButton: NSButton {
    private let normalBackground = NSColor.clear.cgColor
    private let hoverBackground: CGColor
    private let buttonSize: CGFloat

    init(image: NSImage, target: AnyObject?, action: Selector?, size: CGFloat, hoverColor: NSColor) {
        self.buttonSize = size
        self.hoverBackground = hoverColor.cgColor
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        self.image = image
        self.target = target
        self.action = action

        setButtonType(.momentaryChange)
        bezelStyle = .regularSquare
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        alignment = .center
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = min(7, size / 2)
        layer?.masksToBounds = true
        layer?.backgroundColor = normalBackground

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = hoverBackground
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = normalBackground
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: buttonSize, height: buttonSize)
    }
}

private final class ResultTabButton: NSButton {
    var isActive: Bool {
        didSet { updateAppearance() }
    }

    private let profile: AIActionProfile
    private let tabIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let underline = NSView()

    init(profile: AIActionProfile, isActive: Bool) {
        self.profile = profile
        self.isActive = isActive
        super.init(frame: .zero)

        title = ""
        image = nil
        bezelStyle = .regularSquare
        isBordered = false
        alignment = .center
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        tabIconView.image = profile.toolbarIcon
        tabIconView.imageScaling = .scaleProportionallyDown
        tabIconView.translatesAutoresizingMaskIntoConstraints = false
        if profile.customIconPNGBase64 == nil {
            tabIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        }

        titleLabel.stringValue = profile.name
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView(views: [tabIconView, titleLabel])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 6
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        underline.translatesAutoresizingMaskIntoConstraints = false
        underline.wantsLayer = true
        addSubview(underline)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            tabIconView.widthAnchor.constraint(equalToConstant: 16),
            tabIconView.heightAnchor.constraint(equalToConstant: 16),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            underline.leadingAnchor.constraint(equalTo: leadingAnchor),
            underline.trailingAnchor.constraint(equalTo: trailingAnchor),
            underline.bottomAnchor.constraint(equalTo: bottomAnchor),
            underline.heightAnchor.constraint(equalToConstant: 2),
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let font = titleLabel.font ?? .systemFont(ofSize: 13, weight: .semibold)
        let titleWidth = (profile.name as NSString).size(withAttributes: [.font: font]).width
        return NSSize(width: max(78, ceil(titleWidth) + 16 + 6 + 28), height: 44)
    }

    private func updateAppearance() {
        let color = isActive ? ClipWiseColors.accentBlue : NSColor.secondaryLabelColor
        contentTintColor = color
        tabIconView.contentTintColor = color
        titleLabel.textColor = color
        underline.layer?.backgroundColor = isActive ? ClipWiseColors.accentBlue.cgColor : NSColor.clear.cgColor
    }
}

private extension AIActionProfile {
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
