import SwiftUI

struct RegionSelectionView: View {
    let onSelect: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                if let rect = selectionRect(in: geo.size) {
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                VStack {
                    Text("Drag to select region · Esc to cancel")
                        .font(.headline)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 24)
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if startPoint == nil {
                            startPoint = value.startLocation
                        }
                        currentPoint = value.location
                    }
                    .onEnded { value in
                        if let rect = selectionRect(in: geo.size), rect.width > 4, rect.height > 4 {
                            onSelect(convertToScreen(rect: rect, viewSize: geo.size))
                        } else {
                            onCancel()
                        }
                        startPoint = nil
                        currentPoint = nil
                    }
            )
            .onExitCommand(perform: onCancel)
        }
    }

    private func selectionRect(in size: CGSize) -> CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func convertToScreen(rect: CGRect, viewSize: CGSize) -> CGRect {
        guard let screen = NSScreen.main else { return rect }
        let screenFrame = screen.frame
        let scale = screen.backingScaleFactor
        let flippedY = viewSize.height - rect.origin.y - rect.height
        return CGRect(
            x: rect.origin.x * scale,
            y: flippedY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}
