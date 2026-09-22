import AppKit
import Foundation

public struct HotkeyBinding: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: [ModifierKey]

    public init(keyCode: UInt16, modifiers: [ModifierKey]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let windowSwitcherDefault = HotkeyBinding(keyCode: 48, modifiers: [.option])
    public static let screenshotDefault = HotkeyBinding(keyCode: 21, modifiers: [.option, .shift])

    public var displayString: String {
        let modString = modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })
            .map(\.displaySymbol)
            .joined()
        let key = KeyCodeHelper.displayName(for: keyCode)
        return modString + key
    }

    public var carbonFlags: UInt32 {
        modifiers.reduce(0) { $0 | $1.carbonFlag }
    }

    public func matches(event: NSEvent) -> Bool {
        guard event.keyCode == keyCode else { return false }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let expected = Set(modifiers.map(\.nsModifier))
        let actual = Set(ModifierKey.from(nsFlags: flags))
        return actual == expected
    }
}

public enum ModifierKey: String, Codable, CaseIterable, Sendable {
    case command
    case option
    case control
    case shift

    var carbonFlag: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
        case .shift: return UInt32(shiftKey)
        }
    }

    var nsModifier: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }

    var displaySymbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    var sortOrder: Int {
        switch self {
        case .control: return 0
        case .option: return 1
        case .shift: return 2
        case .command: return 3
        }
    }

    static func from(nsFlags: NSEvent.ModifierFlags) -> [ModifierKey] {
        var result: [ModifierKey] = []
        if nsFlags.contains(.command) { result.append(.command) }
        if nsFlags.contains(.option) { result.append(.option) }
        if nsFlags.contains(.control) { result.append(.control) }
        if nsFlags.contains(.shift) { result.append(.shift) }
        return result
    }
}

public enum KeyCodeHelper {
    public static func displayName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 48: return "Tab"
        case 21: return "4"
        case 35: return "P"
        case 49: return "Space"
        default: return "Key(\(keyCode))"
        }
    }
}
