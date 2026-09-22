import AppKit
import CoreGraphics
import ScreenCaptureKit
import UniformTypeIdentifiers

@available(macOS 14.0, *)
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
    static func captureRegion(_ globalRect: CGRect) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        let center = CGPoint(x: globalRect.midX, y: globalRect.midY)
        guard let display = content.displays.first(where: { $0.frame.contains(center) }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }

        let localRect = CGRect(
            x: globalRect.origin.x - display.frame.origin.x,
            y: globalRect.origin.y - display.frame.origin.y,
            width: globalRect.width,
            height: globalRect.height
        )

        guard localRect.width > 0, localRect.height > 0 else {
            throw CaptureError.invalidRegion
        }

        let scale = displayScale(for: display.displayID)
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(localRect.width * scale)
        config.height = Int(localRect.height * scale)
        config.sourceRect = localRect
        config.showsCursor = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: globalRect.width, height: globalRect.height))
    }

    @MainActor
    private static func captureDisplay(_ displayID: CGDirectDisplayID) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }

        let scale = displayScale(for: display.displayID)
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.frame.width * scale)
        config.height = Int(display.frame.height * scale)
        config.showsCursor = true

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: display.frame.width, height: display.frame.height))
    }

    static func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    static func clearClipboard() {
        NSPasteboard.general.clearContents()
    }

    @MainActor
    static func save(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.title = "Save Screenshot"
        panel.nameFieldStringValue = "Screenshot \(formattedTimestamp()).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK,
                  let url = panel.url,
                  let tiff = image.tiffRepresentation,
                  let representation = NSBitmapImageRep(data: tiff),
                  let png = representation.representation(using: .png, properties: [:]) else {
                return
            }

            do {
                try png.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private static func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: Date())
    }

    private static func displayScale(for displayID: CGDirectDisplayID) -> CGFloat {
        NSScreen.screens
            .first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
            }?
            .backingScaleFactor ?? 2.0
    }
}

enum CaptureError: Error, LocalizedError {
    case noScreen
    case noDisplay
    case invalidRegion

    var errorDescription: String? {
        switch self {
        case .noScreen: return "No screen available"
        case .noDisplay: return "No display available for capture"
        case .invalidRegion: return "Invalid capture region"
        }
    }
}
