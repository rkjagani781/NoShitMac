import Foundation

public struct AppConfig: Codable, Sendable {
    public var windowSwitcher: HotkeyBinding
    public var screenshot: HotkeyBinding
    public var windowSwitcherEnabled: Bool
    public var screenshotEnabled: Bool
    public var launchAtLogin: Bool

    public init(
        windowSwitcher: HotkeyBinding = .windowSwitcherDefault,
        screenshot: HotkeyBinding = .screenshotDefault,
        windowSwitcherEnabled: Bool = true,
        screenshotEnabled: Bool = true,
        launchAtLogin: Bool = false
    ) {
        self.windowSwitcher = windowSwitcher
        self.screenshot = screenshot
        self.windowSwitcherEnabled = windowSwitcherEnabled
        self.screenshotEnabled = screenshotEnabled
        self.launchAtLogin = launchAtLogin
    }

    public static let `default` = AppConfig()
}
