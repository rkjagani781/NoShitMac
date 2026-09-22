import AppKit
import PencilKit
import SwiftUI

enum EditorTool: String, CaseIterable {
    case pencil = "Pencil"
    case highlight = "Highlight"
    case crop = "Crop"

    var icon: String {
        switch self {
        case .pencil: return "pencil.tip"
        case .highlight: return "highlighter"
        case .crop: return "crop"
        }
    }
}

struct ScreenshotEditorView: View {
    let sourceImage: NSImage
    let onDone: (NSImage) -> Void
    let onCancel: () -> Void

    @State private var selectedTool: EditorTool = .pencil
    @State private var canvasView = PKCanvasView()
    @State private var cropRect: CGRect?
    @State private var displayImage: NSImage

    init(sourceImage: NSImage, onDone: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void) {
        self.sourceImage = sourceImage
        self.onDone = onDone
        self.onCancel = onCancel
        _displayImage = State(initialValue: sourceImage)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Screenshot Editor")
                    .font(.headline)
                Spacer()
                ForEach(EditorTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                        updateCanvasTool()
                    } label: {
                        Label(tool.rawValue, systemImage: tool.icon)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTool == tool ? .accentColor : .secondary)
                }
            }

            ZStack {
                Image(nsImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selectedTool != .crop {
                    CanvasRepresentable(canvasView: canvasView)
                } else {
                    CropOverlayView(cropRect: $cropRect, imageSize: displayImage.size)
                }
            }
            .frame(minHeight: 360)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Apply Crop") {
                    applyCropAction()
                }
                .disabled(selectedTool != .crop || cropRect == nil)
                Button("Copy & Done") {
                    let final = renderFinalImage()
                    onDone(final)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 860, height: 620)
        .onAppear {
            configureCanvas()
        }
    }

    private func configureCanvas() {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        updateCanvasTool()
    }

    private func updateCanvasTool() {
        switch selectedTool {
        case .pencil:
            canvasView.tool = PKInkingTool(.pen, color: .red, width: 3)
            canvasView.isUserInteractionEnabled = true
        case .highlight:
            canvasView.tool = PKInkingTool(.marker, color: NSColor.yellow.withAlphaComponent(0.5), width: 20)
            canvasView.isUserInteractionEnabled = true
        case .crop:
            canvasView.isUserInteractionEnabled = false
        }
    }

    private func applyCropAction() {
        guard let cropRect, let cropped = applyCrop(to: displayImage, rect: cropRect) else { return }
        displayImage = cropped
        cropRect = nil
        canvasView.drawing = PKDrawing()
        selectedTool = .pencil
        updateCanvasTool()
    }

    private func renderFinalImage() -> NSImage {
        let base = displayImage
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else { return base }

        let size = base.size
        let rendered = NSImage(size: size)
        rendered.lockFocus()

        base.draw(in: NSRect(origin: .zero, size: size))

        let bounds = NSRect(origin: .zero, size: size)
        let image = drawing.image(from: bounds, scale: NSScreen.main?.backingScaleFactor ?? 2)
        image.draw(in: bounds)

        rendered.unlockFocus()
        return rendered
    }
}

private struct CanvasRepresentable: NSViewRepresentable {
    let canvasView: PKCanvasView

    func makeNSView(context: Context) -> PKCanvasView {
        canvasView
    }

    func updateNSView(_ nsView: PKCanvasView, context: Context) {}
}
