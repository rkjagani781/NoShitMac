import AppKit

/// Native macOS drawing overlay (PencilKit/PKCanvasView is iOS/Catalyst only).
final class ScreenshotDrawingView: NSView {
    struct Stroke {
        let tool: EditorTool
        var points: [NSPoint]
    }

    var activeTool: EditorTool = .pencil
    private(set) var strokes: [Stroke] = []
    private var currentStroke: Stroke?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard activeTool == .pencil || activeTool == .highlight else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentStroke = Stroke(tool: activeTool, points: [point])
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard var stroke = currentStroke else { return }
        stroke.points.append(convert(event.locationInWindow, from: nil))
        currentStroke = stroke
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var stroke = currentStroke else { return }
        stroke.points.append(convert(event.locationInWindow, from: nil))
        strokes.append(stroke)
        currentStroke = nil
        needsDisplay = true
    }

    func clear() {
        strokes.removeAll()
        currentStroke = nil
        needsDisplay = true
    }

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        needsDisplay = true
    }

    var canUndo: Bool {
        !strokes.isEmpty
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for stroke in strokes {
            draw(stroke)
        }
        if let currentStroke {
            draw(currentStroke)
        }
    }

    private func draw(_ stroke: Stroke) {
        guard stroke.points.count > 1 else { return }

        let path = NSBezierPath()
        path.lineWidth = stroke.tool == .highlight ? 20 : 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        switch stroke.tool {
        case .pencil:
            NSColor.red.setStroke()
        case .highlight:
            NSColor.yellow.withAlphaComponent(0.45).setStroke()
        case .crop:
            return
        }

        path.move(to: stroke.points[0])
        for point in stroke.points.dropFirst() {
            path.line(to: point)
        }
        path.stroke()
    }

    /// Renders strokes onto the base image, mapping view coordinates through the aspect-fit rect.
    func render(on image: NSImage, viewSize: NSSize) -> NSImage {
        guard !strokes.isEmpty else { return image }

        let imageSize = image.size
        let fit = Self.fittedRect(imageSize: imageSize, in: viewSize)
        guard fit.width > 0, fit.height > 0 else { return image }

        let output = NSImage(size: imageSize)
        output.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: imageSize))

        for stroke in strokes {
            guard stroke.points.count > 1 else { continue }
            let path = NSBezierPath()
            path.lineWidth = (stroke.tool == .highlight ? 20 : 3) * (imageSize.width / fit.width)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            switch stroke.tool {
            case .pencil: NSColor.red.setStroke()
            case .highlight: NSColor.yellow.withAlphaComponent(0.45).setStroke()
            case .crop: continue
            }

            let mapped = stroke.points.map { mapPointToImage($0, fittedRect: fit, imageSize: imageSize) }
            path.move(to: mapped[0])
            for point in mapped.dropFirst() {
                path.line(to: point)
            }
            path.stroke()
        }

        output.unlockFocus()
        return output
    }

    static func fittedRect(imageSize: NSSize, in viewSize: NSSize) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let ratio = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let width = imageSize.width * ratio
        let height = imageSize.height * ratio
        let x = (viewSize.width - width) / 2
        let y = (viewSize.height - height) / 2
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func mapPointToImage(_ point: NSPoint, fittedRect: NSRect, imageSize: NSSize) -> NSPoint {
        let nx = (point.x - fittedRect.origin.x) / fittedRect.width
        let ny = (point.y - fittedRect.origin.y) / fittedRect.height
        return NSPoint(x: nx * imageSize.width, y: ny * imageSize.height)
    }
}
