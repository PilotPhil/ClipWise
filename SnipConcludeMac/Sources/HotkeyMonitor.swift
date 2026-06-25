import AppKit
import CoreGraphics

final class HotkeyMonitor {
    private let settings: AppSettings
    private let action: @MainActor @Sendable () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(settings: AppSettings, action: @escaping @MainActor @Sendable () -> Void) {
        self.settings = settings
        self.action = action
    }

    func start() {
        stop()
        if startEventTap() {
            return
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func startEventTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(event: event, type: type)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(event: CGEvent, type: CGEventType) {
        guard type == .keyDown else { return }
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
        guard matches(event) else { return }
        Task { @MainActor [action] in action() }
    }

    private func handle(_ event: NSEvent) {
        guard matches(event) else { return }
        Task { @MainActor [action] in action() }
    }

    private func matches(_ event: NSEvent) -> Bool {
        let hotkey = settings.captureHotkey
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.control) == hotkey.control else { return false }
        guard flags.contains(.shift) == hotkey.shift else { return false }
        guard flags.contains(.option) == hotkey.option else { return false }
        guard flags.contains(.command) == hotkey.command else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == hotkey.key.lowercased()
    }

    private func matches(_ event: CGEvent) -> Bool {
        let hotkey = settings.captureHotkey
        let flags = event.flags
        guard flags.contains(.maskControl) == hotkey.control else { return false }
        guard flags.contains(.maskShift) == hotkey.shift else { return false }
        guard flags.contains(.maskAlternate) == hotkey.option else { return false }
        guard flags.contains(.maskCommand) == hotkey.command else { return false }
        guard let keyCode = Self.keyCode(for: hotkey.key) else { return false }
        return CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)) == keyCode
    }

    private static func keyCode(for key: String) -> CGKeyCode? {
        switch key.lowercased() {
        case "a": return 0
        case "s": return 1
        case "d": return 2
        case "f": return 3
        case "h": return 4
        case "g": return 5
        case "z": return 6
        case "x": return 7
        case "c": return 8
        case "v": return 9
        case "b": return 11
        case "q": return 12
        case "w": return 13
        case "e": return 14
        case "r": return 15
        case "y": return 16
        case "t": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "6": return 22
        case "5": return 23
        case "=": return 24
        case "9": return 25
        case "7": return 26
        case "-": return 27
        case "8": return 28
        case "0": return 29
        case "]": return 30
        case "o": return 31
        case "u": return 32
        case "[": return 33
        case "i": return 34
        case "p": return 35
        case "l": return 37
        case "j": return 38
        case "'": return 39
        case "k": return 40
        case ";": return 41
        case "\\": return 42
        case ",": return 43
        case "/": return 44
        case "n": return 45
        case "m": return 46
        case ".": return 47
        default: return nil
        }
    }
}
