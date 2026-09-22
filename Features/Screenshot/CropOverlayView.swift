import SwiftUI

struct CropOverlayView: View {
    @Binding var cropRect: CGRect?
    let imageSize: CGSize

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let rect = activeRect(in: geo.size) {
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                        dragCurrent = value.location
                    }
                    .onEnded { value in
                        if let rect = activeRect(in: geo.size), rect.width > 8, rect.height > 8 {
                            cropRect = mapToImage(rect: rect, viewSize: geo.size)
                        }
                        dragStart = nil
                        dragCurrent = nil
                    }
            )
        }
    }

    private func activeRect(in viewSize: CGSize) -> CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    private func mapToImage(rect: CGRect, viewSize: CGSize) -> CGRect {
        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height
        return CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
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
