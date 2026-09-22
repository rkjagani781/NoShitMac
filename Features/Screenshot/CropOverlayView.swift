import SwiftUI

struct CropOverlayView: View {
    @Binding var cropRect: CGRect?
    let imageSize: CGSize

    @State private var dragStart: CGPoint?
    @State private var selectionRect: CGRect?

    var body: some View {
        GeometryReader { geo in
            let imageRect = ScreenshotDrawingView.fittedRect(
                imageSize: imageSize,
                in: geo.size
            )

            ZStack {
                Color.black.opacity(0.28)

                if let rect = selectionRect {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .overlay(
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                        .overlay(alignment: .topLeading) { cropHandle }
                        .overlay(alignment: .topTrailing) { cropHandle }
                        .overlay(alignment: .bottomLeading) { cropHandle }
                        .overlay(alignment: .bottomTrailing) { cropHandle }
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let start = clamped(value.startLocation, to: imageRect)
                        let current = clamped(value.location, to: imageRect)
                        if dragStart == nil { dragStart = start }
                        selectionRect = rectangle(from: dragStart ?? start, to: current)
                    }
                    .onEnded { _ in
                        if let rect = selectionRect, rect.width > 8, rect.height > 8 {
                            cropRect = mapToImage(rect: rect, imageRect: imageRect)
                        } else {
                            selectionRect = nil
                            cropRect = nil
                        }
                        dragStart = nil
                    }
            )
        }
    }

    private var cropHandle: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
            .frame(width: 8, height: 8)
            .offset(
                x: selectionRect == nil ? 0 : 0,
                y: selectionRect == nil ? 0 : 0
            )
    }

    private func rectangle(from start: CGPoint, to current: CGPoint) -> CGRect {
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    private func clamped(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func mapToImage(rect: CGRect, imageRect: CGRect) -> CGRect {
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height
        return CGRect(
            x: (rect.origin.x - imageRect.origin.x) * scaleX,
            y: (rect.origin.y - imageRect.origin.y) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }
}

func applyCrop(to image: NSImage, rect: CGRect) -> NSImage? {
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let scaled = CGRect(
        x: rect.origin.x,
        y: rect.origin.y,
        width: rect.width,
        height: rect.height
    )
    guard let cropped = cg.cropping(to: scaled) else { return nil }
    return NSImage(cgImage: cropped, size: NSSize(width: scaled.width, height: scaled.height))
}
