import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("SnipConcludeMac/Assets", isDirectory: true)
let iconset = assets.appendingPathComponent("ClipWise.iconset", isDirectory: true)
let sourceResources = root.appendingPathComponent("SnipConcludeMac/Sources/Resources", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: sourceResources, withIntermediateDirectories: true)

func image(size: CGFloat, draw: (CGRect) -> Void) -> NSImage {
    let pixels = Int(size.rounded())
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap context")
    }

    rep.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Failed to create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    draw(CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

func pngData(_ image: NSImage) -> Data {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to encode PNG")
    }
    return png
}

func savePNG(_ image: NSImage, to url: URL) throws {
    try pngData(image).write(to: url)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int = 4) -> NSBezierPath {
    let path = NSBezierPath()
    let total = points * 2
    for index in 0..<total {
        let angle = CGFloat(index) * .pi / CGFloat(points) - .pi / 2
        let radius = index.isMultiple(of: 2) ? outer : inner
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        if index == 0 {
            path.move(to: point)
        } else {
            path.line(to: point)
        }
    }
    path.close()
    return path
}

func drawAppIcon(in rect: CGRect) {
    let scale = rect.width / 1024
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    NSColor.clear.setFill()
    rect.fill()

    let base = rect.insetBy(dx: s(64), dy: s(64))
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -s(18))
    shadow.shadowBlurRadius = s(34)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.set()

    let basePath = roundedRect(base, radius: s(214))
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.54, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.83, blue: 0.92, alpha: 1),
    ])!
    gradient.draw(in: basePath, angle: 45)
    NSShadow().set()

    let inner = base.insetBy(dx: s(76), dy: s(88))
    NSColor.white.withAlphaComponent(0.18).setStroke()
    let frame = roundedRect(inner, radius: s(82))
    frame.lineWidth = s(18)
    frame.stroke()

    NSColor.white.setStroke()
    let cornerWidth = s(164)
    let cornerInset = s(32)
    let cornerLine = s(28)
    let corners = NSBezierPath()
    corners.lineWidth = cornerLine
    corners.lineCapStyle = .round
    corners.lineJoinStyle = .round

    let minX = inner.minX + cornerInset
    let maxX = inner.maxX - cornerInset
    let minY = inner.minY + cornerInset
    let maxY = inner.maxY - cornerInset

    corners.move(to: CGPoint(x: minX, y: maxY - cornerWidth))
    corners.line(to: CGPoint(x: minX, y: maxY))
    corners.line(to: CGPoint(x: minX + cornerWidth, y: maxY))

    corners.move(to: CGPoint(x: maxX - cornerWidth, y: maxY))
    corners.line(to: CGPoint(x: maxX, y: maxY))
    corners.line(to: CGPoint(x: maxX, y: maxY - cornerWidth))

    corners.move(to: CGPoint(x: minX, y: minY + cornerWidth))
    corners.line(to: CGPoint(x: minX, y: minY))
    corners.line(to: CGPoint(x: minX + cornerWidth, y: minY))

    corners.move(to: CGPoint(x: maxX - cornerWidth, y: minY))
    corners.line(to: CGPoint(x: maxX, y: minY))
    corners.line(to: CGPoint(x: maxX, y: minY + cornerWidth))
    corners.stroke()

    let document = CGRect(x: rect.midX - s(196), y: rect.midY - s(164), width: s(318), height: s(318))
    NSColor.white.withAlphaComponent(0.96).setFill()
    roundedRect(document, radius: s(44)).fill()
    NSColor(calibratedRed: 0.12, green: 0.31, blue: 0.57, alpha: 0.18).setStroke()
    let docBorder = roundedRect(document, radius: s(44))
    docBorder.lineWidth = s(8)
    docBorder.stroke()

    NSColor(calibratedRed: 0.14, green: 0.28, blue: 0.46, alpha: 0.72).setStroke()
    for offset in [s(78), s(142), s(206)] {
        let line = NSBezierPath()
        line.lineWidth = s(18)
        line.lineCapStyle = .round
        line.move(to: CGPoint(x: document.minX + s(58), y: document.maxY - offset))
        line.line(to: CGPoint(x: document.maxX - s(58), y: document.maxY - offset))
        line.stroke()
    }

    NSColor.white.setFill()
    starPath(center: CGPoint(x: rect.midX + s(250), y: rect.midY + s(218)), outer: s(104), inner: s(28)).fill()
    NSColor(calibratedRed: 0.03, green: 0.37, blue: 0.78, alpha: 0.96).setFill()
    starPath(center: CGPoint(x: rect.midX + s(250), y: rect.midY + s(218)), outer: s(72), inner: s(18)).fill()
    NSColor.white.withAlphaComponent(0.92).setFill()
    starPath(center: CGPoint(x: rect.midX + s(326), y: rect.midY + s(104)), outer: s(42), inner: s(12)).fill()
}

func drawStatusIcon(in rect: CGRect) {
    NSColor.clear.setFill()
    rect.fill()
    let scale = rect.width / 36
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    NSColor.black.setStroke()
    let lineWidth = s(2.6)
    let frame = CGRect(x: s(5), y: s(7), width: s(22), height: s(22))
    let path = NSBezierPath()
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round

    path.move(to: CGPoint(x: frame.minX, y: frame.maxY - s(7)))
    path.line(to: CGPoint(x: frame.minX, y: frame.maxY))
    path.line(to: CGPoint(x: frame.minX + s(7), y: frame.maxY))
    path.move(to: CGPoint(x: frame.maxX - s(7), y: frame.maxY))
    path.line(to: CGPoint(x: frame.maxX, y: frame.maxY))
    path.line(to: CGPoint(x: frame.maxX, y: frame.maxY - s(7)))
    path.move(to: CGPoint(x: frame.minX, y: frame.minY + s(7)))
    path.line(to: CGPoint(x: frame.minX, y: frame.minY))
    path.line(to: CGPoint(x: frame.minX + s(7), y: frame.minY))
    path.move(to: CGPoint(x: frame.maxX - s(7), y: frame.minY))
    path.line(to: CGPoint(x: frame.maxX, y: frame.minY))
    path.line(to: CGPoint(x: frame.maxX, y: frame.minY + s(7)))
    path.stroke()

    NSColor.black.setFill()
    starPath(center: CGPoint(x: s(27.5), y: s(24.5)), outer: s(5.2), inner: s(1.5)).fill()
    starPath(center: CGPoint(x: s(29), y: s(13)), outer: s(2.8), inner: s(0.9)).fill()
}

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in iconSizes {
    try savePNG(image(size: size, draw: drawAppIcon), to: iconset.appendingPathComponent(name))
}

try savePNG(image(size: 1024, draw: drawAppIcon), to: assets.appendingPathComponent("ClipWise-AppIcon-1024.png"))
try savePNG(image(size: 18, draw: drawStatusIcon), to: assets.appendingPathComponent("StatusBarTemplate.png"))
try savePNG(image(size: 36, draw: drawStatusIcon), to: assets.appendingPathComponent("StatusBarTemplate@2x.png"))
try savePNG(image(size: 18, draw: drawStatusIcon), to: sourceResources.appendingPathComponent("StatusBarTemplate.png"))
try savePNG(image(size: 36, draw: drawStatusIcon), to: sourceResources.appendingPathComponent("StatusBarTemplate@2x.png"))

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconset.path,
    "-o", assets.appendingPathComponent("ClipWise.icns").path,
]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

print("Generated icons in \(assets.path)")
