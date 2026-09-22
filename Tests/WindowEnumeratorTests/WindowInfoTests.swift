@testable import NoShitMac
import XCTest

final class WindowInfoTests: XCTestCase {
    func testWindowEnumeratorReturnsArray() {
        let windows = WindowEnumerator.enumerate()
        // May be empty in CI without GUI session; ensure no crash.
        XCTAssertNotNil(windows)
    }
}
