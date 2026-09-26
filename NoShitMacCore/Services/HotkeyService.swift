import AppKit
import Foundation

public enum HotkeyEvent: Sendable {
    case keyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isRepeat: Bool)
    case keyUp(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
    case flagsChanged(modifiers: NSEvent.ModifierFlags)
}

/// Return `true` from a handler to swallow the CGEvent (AltTab-style).
public typealias HotkeyHandler = (HotkeyEvent) -> Bool

@MainActor
public final class HotkeyService {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handlers: [String: HotkeyHandler] = [:]
    private var tapBox: HotkeyServiceBox?

    public init() {}

    public func register(id: String, handler: @escaping HotkeyHandler) {
        handlers[id] = handler
        ensureTapRunning()
    }

    public func unregister(id: String) {
        handlers.removeValue(forKey: id)
        if handlers.isEmpty {
            stop()
        }
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        tapBox = nil
        handlers.removeAll()
    }

    /// Returns whether any handler consumed the event.
    fileprivate func dispatch(_ event: HotkeyEvent) -> Bool {
        var consumed = false
        for handler in handlers.values {
            if handler(event) { consumed = true }
        }
        return consumed
    }

    fileprivate func reenableTapIfNeeded(type: CGEventType) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                NSLog("NoShitMac: re-enabled event tap after \(type.rawValue)")
            }
        }
    }

    private func ensureTapRunning() {
        guard eventTap == nil else { return }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let box = HotkeyServiceBox(service: self)
        tapBox = box
        // Lifetime owned by `tapBox`; do not passRetained (would leak / double-free).
        let pointer = Unmanaged.passUnretained(box).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let serviceBox = Unmanaged<HotkeyServiceBox>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                serviceBox.reenableTap(type: type)
                return Unmanaged.passUnretained(event)
            }

            let consumed = serviceBox.handleSync(type: type, event: event)
            return consumed ? nil : Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: pointer
        ) else {
            NSLog("NoShitMac: failed to create event tap — grant Input Monitoring permission")
            tapBox = nil
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

/// Tap is installed on the main run-loop, so the callback runs on the main thread.
private final class HotkeyServiceBox: @unchecked Sendable {
    weak var service: HotkeyService?

    init(service: HotkeyService) {
        self.service = service
    }

    func reenableTap(type: CGEventType) {
        MainActor.assumeIsolated {
            service?.reenableTapIfNeeded(type: type)
        }
    }

    func handleSync(type: CGEventType, event: CGEvent) -> Bool {
        guard let hotkeyEvent = Self.parse(type: type, event: event) else { return false }
        // Main-runloop tap → already on main; never async+wait (deadlock).
        return MainActor.assumeIsolated {
            service?.dispatch(hotkeyEvent) ?? false
        }
    }

    private static func parse(type: CGEventType, event: CGEvent) -> HotkeyEvent? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        switch type {
        case .keyDown:
            return .keyDown(keyCode: keyCode, modifiers: nsFlags, isRepeat: isRepeat)
        case .keyUp:
            return .keyUp(keyCode: keyCode, modifiers: nsFlags)
        case .flagsChanged:
            return .flagsChanged(modifiers: nsFlags)
        default:
            return nil
        }
    }
}

public enum HotkeyMatcher {
    public static func matches(binding: HotkeyBinding, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard keyCode == binding.keyCode else { return false }
        let actual = Set(ModifierKey.from(nsFlags: modifiers.intersection([.command, .option, .control, .shift])))
        let expected = Set(binding.modifiers)
        return actual == expected
    }

    /// Binding key + required modifiers; Shift may be present for reverse cycling.
    public static func matchesAllowingShift(
        binding: HotkeyBinding,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        guard keyCode == binding.keyCode else { return false }
        guard binding.allModifiersHeld(modifiers) else { return false }
        let withoutShift = modifiers.intersection([.command, .option, .control, .shift]).subtracting(.shift)
        let actual = Set(ModifierKey.from(nsFlags: withoutShift))
        let expected = Set(binding.modifiers.filter { $0 != .shift })
        return actual == expected
    }
}
