import NoShitMacCore
import XCTest

final class AppConfigTests: XCTestCase {
    func testDefaultHotkeys() {
        let config = AppConfig.default
        XCTAssertEqual(config.windowSwitcher.keyCode, 48)
        XCTAssertTrue(config.windowSwitcher.modifiers.contains(.option))
        XCTAssertEqual(config.screenshot.keyCode, 21)
        XCTAssertTrue(config.screenshot.modifiers.contains(.shift))
    }

    func testHotkeyDisplayString() {
        let binding = HotkeyBinding.windowSwitcherDefault
        XCTAssertTrue(binding.displayString.contains("Tab"))
    }

    func testConfigRoundTripJSON() throws {
        let config = AppConfig(
            windowSwitcher: HotkeyBinding(keyCode: 35, modifiers: [.command, .shift]),
            screenshot: .screenshotDefault,
            windowSwitcherEnabled: true,
            screenshotEnabled: false,
            launchAtLogin: true
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.windowSwitcher.keyCode, 35)
        XCTAssertFalse(decoded.screenshotEnabled)
        XCTAssertTrue(decoded.launchAtLogin)
    }
}
