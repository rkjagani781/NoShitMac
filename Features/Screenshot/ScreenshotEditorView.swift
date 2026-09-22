import AppKit
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

@MainActor
final class EditorCanvasController: ObservableObject {
    let drawingView = ScreenshotDrawingView()

    func applyTool(_ tool: EditorTool) {
        drawingView.activeTool = tool
    }

    func clearDrawing() {
        drawingView.clear()
    }

    func render(on base: NSImage, viewSize: NSSize) -> NSImage {
        drawingView.render(on: base, viewSize: viewSize)
    }
}

struct ScreenshotEditorView: View {
    let sourceImage: NSImage
    let onDone: (NSImage) -> Void
    let onCancel: () -> Void

    @StateObject private var canvasController = EditorCanvasController()
    @State private var selectedTool: EditorTool = .pencil
    @State private var cropRect: CGRect?
    @State private var displayImage: NSImage
    @State private var canvasSize: CGSize = .zero

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
                        canvasController.applyTool(tool)
                    } label: {
                        Label(tool.rawValue, systemImage: tool.icon)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTool == tool ? .accentColor : .secondary)
                }
            }

            GeometryReader { geo in
                ZStack {
                    Image(nsImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if selectedTool != .crop {
                        DrawingCanvasRepresentable(drawingView: canvasController.drawingView)
                    } else {
                        CropOverlayView(cropRect: $cropRect, imageSize: displayImage.size)
                    }
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { canvasSize = $0 }
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
                    let final = canvasController.render(on: displayImage, viewSize: NSSize(width: canvasSize.width, height: canvasSize.height))
                    onDone(final)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 860, height: 620)
        .onAppear {
            canvasController.applyTool(selectedTool)
        }
    }

    private func applyCropAction() {
        guard let rect = cropRect, let cropped = applyCrop(to: displayImage, rect: rect) else { return }
        displayImage = cropped
        self.cropRect = nil
        canvasController.clearDrawing()
        selectedTool = .pencil
        canvasController.applyTool(.pencil)
    }
}

private struct DrawingCanvasRepresentable: NSViewRepresentable {
    let drawingView: ScreenshotDrawingView

    func makeNSView(context: Context) -> ScreenshotDrawingView {
        drawingView
    }

    func updateNSView(_ nsView: ScreenshotDrawingView, context: Context) {}
}
