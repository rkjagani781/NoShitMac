import Foundation

public enum ScreenshotCaptureMode: String, Codable, Sendable, CaseIterable {
    case region
    case fullScreen

    public var displayName: String {
        switch self {
        case .region: return "Region"
        case .fullScreen: return "Full Screen"
        }
    }
}

public struct AppConfig: Codable, Sendable {
    public var windowSwitcher: HotkeyBinding
    public var screenshot: HotkeyBinding
    public var windowSwitcherEnabled: Bool
    public var screenshotEnabled: Bool
    public var screenshotCaptureMode: ScreenshotCaptureMode
    public var launchAtLogin: Bool

    public init(
        windowSwitcher: HotkeyBinding = .windowSwitcherDefault,
        screenshot: HotkeyBinding = .screenshotDefault,
        windowSwitcherEnabled: Bool = true,
        screenshotEnabled: Bool = true,
        screenshotCaptureMode: ScreenshotCaptureMode = .region,
        launchAtLogin: Bool = false
    ) {
        self.windowSwitcher = windowSwitcher
        self.screenshot = screenshot
        self.windowSwitcherEnabled = windowSwitcherEnabled
        self.screenshotEnabled = screenshotEnabled
        self.screenshotCaptureMode = screenshotCaptureMode
        self.launchAtLogin = launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        windowSwitcher = try container.decode(HotkeyBinding.self, forKey: .windowSwitcher)
        screenshot = try container.decode(HotkeyBinding.self, forKey: .screenshot)
        windowSwitcherEnabled = try container.decodeIfPresent(Bool.self, forKey: .windowSwitcherEnabled) ?? true
        screenshotEnabled = try container.decodeIfPresent(Bool.self, forKey: .screenshotEnabled) ?? true
        screenshotCaptureMode = try container.decodeIfPresent(ScreenshotCaptureMode.self, forKey: .screenshotCaptureMode) ?? .region
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windowSwitcher, forKey: .windowSwitcher)
        try container.encode(screenshot, forKey: .screenshot)
        try container.encode(windowSwitcherEnabled, forKey: .windowSwitcherEnabled)
        try container.encode(screenshotEnabled, forKey: .screenshotEnabled)
        try container.encode(screenshotCaptureMode, forKey: .screenshotCaptureMode)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
    }

    private enum CodingKeys: String, CodingKey {
        case windowSwitcher
        case screenshot
        case windowSwitcherEnabled
        case screenshotEnabled
        case screenshotCaptureMode
        case launchAtLogin
    }

    public static let `default` = AppConfig()
}
