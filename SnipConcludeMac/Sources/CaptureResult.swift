import AppKit

struct CaptureResult {
    let pngData: Data
    let screenRect: CGRect
    let image: NSImage
}

enum CaptureError: LocalizedError {
    case noImage
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "截图失败。请确认已授予屏幕录制权限。"
        case .pngEncodingFailed:
            return "截图 PNG 编码失败。"
        }
    }
}

