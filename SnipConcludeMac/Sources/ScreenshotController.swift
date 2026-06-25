import AppKit
import CoreGraphics

@MainActor
final class ScreenshotController {
    private var overlayWindow: SelectionWindow?

    func startSelection(completion: @escaping @MainActor (Result<CaptureResult, Error>) -> Void) {
        let frame = NSScreen.screens
            .map(\.frame)
            .reduce(NSScreen.main?.frame ?? .zero) { $0.union($1) }

        let window = SelectionWindow(frame: frame)
        window.onCancel = { [weak self] in
            self?.overlayWindow = nil
        }
        window.onSelect = { [weak self] rect in
            self?.overlayWindow = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                completion(Result { try Self.capture(rect: rect) })
            }
        }
        overlayWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private static func capture(rect: CGRect) throws -> CaptureResult {
        let captureRect = quartzRect(fromAppKitRect: rect)
        guard let image = CGWindowListCreateImage(captureRect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) else {
            throw CaptureError.noImage
        }
        let nsImage = NSImage(cgImage: image, size: rect.size)
        guard let pngData = nsImage.pngData else {
            throw CaptureError.pngEncodingFailed
        }
        return CaptureResult(pngData: pngData, screenRect: rect, image: nsImage)
    }

    private static func quartzRect(fromAppKitRect rect: CGRect) -> CGRect {
        let desktopFrame = NSScreen.screens
            .map(\.frame)
            .reduce(NSScreen.main?.frame ?? .zero) { $0.union($1) }
        return CGRect(
            x: rect.minX,
            y: desktopFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        ).integral
    }
}

private final class SelectionWindow: NSWindow {
    var onSelect: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(frame: CGRect) {
        let view = SelectionView(frame: CGRect(origin: .zero, size: frame.size))
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.contentView = view
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        view.onSelect = { [weak self] rect in
            self?.orderOut(nil)
            self?.onSelect?(rect)
        }
        view.onCancel = { [weak self] in
            self?.orderOut(nil)
            self?.onCancel?()
        }
    }

    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    var onSelect: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private var start: CGPoint?
    private var current: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()

        guard let rect = selectionRect else {
            drawHint()
            return
        }

        NSColor.clear.setFill()
        rect.fill(using: .clear)
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()

        drawSizeLabel(rect)
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width > 8, rect.height > 8 else {
            onCancel?()
            return
        }
        let screenOrigin = window?.frame.origin ?? .zero
        let screenRect = CGRect(
            x: screenOrigin.x + rect.minX,
            y: screenOrigin.y + rect.minY,
            width: rect.width,
            height: rect.height
        )
        onSelect?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    private var selectionRect: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y)
        )
    }

    private func drawHint() {
        let text = "拖拽选择截图区域，Esc 取消"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let rect = CGRect(
            x: bounds.midX - size.width / 2 - 16,
            y: bounds.midY - size.height / 2 - 10,
            width: size.width + 32,
            height: size.height + 20
        )
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        text.draw(at: CGPoint(x: rect.minX + 16, y: rect.minY + 10), withAttributes: attrs)
    }

    private func drawSizeLabel(_ rect: CGRect) {
        let text = "\(Int(rect.width)) x \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let labelRect = CGRect(
            x: rect.minX,
            y: min(bounds.maxY - 28, rect.maxY + 8),
            width: size.width + 16,
            height: size.height + 8
        )
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5).fill()
        text.draw(at: CGPoint(x: labelRect.minX + 8, y: labelRect.minY + 4), withAttributes: attrs)
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
