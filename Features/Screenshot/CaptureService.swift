import AppKit
import CoreGraphics
import ScreenCaptureKit

enum CaptureService {
    @MainActor
    static func captureFullScreen() async throws -> NSImage {
        guard let screen = NSScreen.main else {
            throw CaptureError.noScreen
        }
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        return try await captureDisplay(displayID)
    }

    @MainActor
    static func captureRegion(_ rect: CGRect) async throws -> NSImage {
        guard let screen = NSScreen.main else {
            throw CaptureError.noScreen
        }
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(rect.width * 2)
        config.height = Int(rect.height * 2)
        config.sourceRect = rect
        config.showsCursor = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: rect.width, height: rect.height))
    }

    @MainActor
    private static func captureDisplay(_ displayID: CGDirectDisplayID) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.showsCursor = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))
    }

    static func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

enum CaptureError: Error, LocalizedError {
    case noScreen
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noScreen: return "No screen available"
        case .noDisplay: return "No display available for capture"
        }
    }
}
