import AppKit
import Carbon.HIToolbox
import Foundation

public enum HotkeyEvent: Sendable {
    case keyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
    case keyUp(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
    case flagsChanged(modifiers: NSEvent.ModifierFlags)
}

@MainActor
public final class HotkeyService {
    public typealias Handler = (HotkeyEvent) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handlers: [String: Handler] = [:]
    private var tapBox: HotkeyServiceBox?

    public init() {}

    public func register(id: String, handler: @escaping Handler) {
        handlers[id] = handler
        ensureTapRunning()
    }

    public func unregister(id: String) {
        handlers.removeValue(forKey: id)
        if handlers.isEmpty {
            stop()
        }
    }

    public func startGlobal(handler: @escaping Handler) {
        handlers["__global__"] = handler
        ensureTapRunning()
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

    fileprivate func dispatch(_ event: HotkeyEvent) {
        for handler in handlers.values {
            handler(event)
        }
    }

    private func ensureTapRunning() {
        guard eventTap == nil else { return }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let box = HotkeyServiceBox(service: self)
        tapBox = box
        let pointer = Unmanaged.passRetained(box).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let serviceBox = Unmanaged<HotkeyServiceBox>.fromOpaque(userInfo).takeUnretainedValue()
            serviceBox.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
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
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

/// Bridges the synchronous CGEventTap C callback to MainActor-isolated handlers.
private final class HotkeyServiceBox: @unchecked Sendable {
    weak var service: HotkeyService?

    init(service: HotkeyService) {
        self.service = service
    }

    func handle(type: CGEventType, event: CGEvent) {
        guard let hotkeyEvent = Self.parse(type: type, event: event) else { return }
        Task { @MainActor [weak service] in
            service?.dispatch(hotkeyEvent)
        }
    }

    private static func parse(type: CGEventType, event: CGEvent) -> HotkeyEvent? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

        switch type {
        case .keyDown:
            return .keyDown(keyCode: keyCode, modifiers: nsFlags)
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
}
