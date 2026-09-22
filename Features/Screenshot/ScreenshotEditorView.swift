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

    var pencilColor: NSColor {
        get { drawingView.pencilColor }
        set { drawingView.pencilColor = newValue }
    }

    var highlightColor: NSColor {
        get { drawingView.highlightColor }
        set { drawingView.highlightColor = newValue }
    }

    func applyTool(_ tool: EditorTool) {
        drawingView.activeTool = tool
    }

    func clearDrawing() {
        drawingView.clear()
    }

    func undo() {
        drawingView.undo()
    }

    func render(on base: NSImage, viewSize: NSSize) -> NSImage {
        drawingView.render(on: base, viewSize: viewSize)
    }
}

struct ScreenshotEditorView: View {
    let sourceImage: NSImage
    let onCopy: (NSImage) -> Void
    let onSave: (NSImage) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @StateObject private var canvasController = EditorCanvasController()
    @State private var selectedTool: EditorTool = .pencil
    @State private var cropRect: CGRect?
    @State private var displayImage: NSImage
    @State private var canvasSize: CGSize = .zero
    @State private var copied = false
    @State private var pencilColorIndex = 0
    @State private var highlightColorIndex = 0

    init(
        sourceImage: NSImage,
        onCopy: @escaping (NSImage) -> Void,
        onSave: @escaping (NSImage) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.sourceImage = sourceImage
        self.onCopy = onCopy
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _displayImage = State(initialValue: sourceImage)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            canvas
            Divider()
            actionBar
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            canvasController.applyTool(selectedTool)
            canvasController.pencilColor = EditorColorPalette.pencil[pencilColorIndex]
            canvasController.highlightColor = EditorColorPalette.highlight[highlightColorIndex]
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            Text("Edit Screenshot")
                .font(.headline)

            Divider()
                .frame(height: 20)

            HStack(spacing: 4) {
                ForEach(EditorTool.allCases, id: \.self) { tool in
                    Button {
                        select(tool)
                    } label: {
                        Image(systemName: tool.icon)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTool == tool ? .accentColor : nil)
                    .help(tool.rawValue)
                }
            }

            if selectedTool == .crop {
                Button("Apply Crop") {
                    applyCropAction()
                }
                .disabled(selectedTool != .crop || cropRect == nil)
                .buttonStyle(.borderedProminent)
            }

            if selectedTool == .pencil {
                EditorColorPaletteView(
                    colors: EditorColorPalette.pencil,
                    selectedIndex: $pencilColorIndex
                ) { color in
                    canvasController.pencilColor = color
                }
            }

            if selectedTool == .highlight {
                EditorColorPaletteView(
                    colors: EditorColorPalette.highlight,
                    selectedIndex: $highlightColorIndex
                ) { color in
                    canvasController.highlightColor = color
                }
            }

            Spacer()

            Button {
                canvasController.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .help("Undo last annotation")
            .keyboardShortcut("z", modifiers: .command)

            Button {
                canvasController.clearDrawing()
            } label: {
                Image(systemName: "eraser")
            }
            .buttonStyle(.borderless)
            .help("Clear annotations")
        }
        .padding(.horizontal, 18)
        .padding(.top, 30)
        .padding(.bottom, 10)
        .background(.bar)
    }

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                Image(nsImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)

                if selectedTool != .crop {
                    DrawingCanvasRepresentable(drawingView: canvasController.drawingView)
                } else {
                    CropOverlayView(cropRect: $cropRect, imageSize: displayImage.size)
                }
            }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
        }
        .frame(minHeight: 360)
        .padding(20)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
            Text("\(Int(displayImage.size.width)) × \(Int(displayImage.size.height))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if copied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help("Discard this screenshot")

            Button {
                onSave(finalImage)
            } label: {
                Label("Save…", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)

            Button {
                onCopy(finalImage)
                withAnimation { copied = true }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Done") {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var finalImage: NSImage {
        canvasController.render(
            on: displayImage,
            viewSize: NSSize(width: canvasSize.width, height: canvasSize.height)
        )
    }

    private func select(_ tool: EditorTool) {
        selectedTool = tool
        cropRect = nil
        canvasController.applyTool(tool)
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

private struct EditorColorPaletteView: View {
    let colors: [NSColor]
    @Binding var selectedIndex: Int
    let onSelect: (NSColor) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(colors.indices, id: \.self) { index in
                let color = colors[index]
                Button {
                    selectedIndex = index
                    onSelect(color)
                } label: {
                    Circle()
                        .fill(Color(nsColor: color))
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    selectedIndex == index ? Color.accentColor : Color.primary.opacity(0.15),
                                    lineWidth: selectedIndex == index ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .help("Select color")
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct DrawingCanvasRepresentable: NSViewRepresentable {
    let drawingView: ScreenshotDrawingView

    func makeNSView(context: Context) -> ScreenshotDrawingView {
        drawingView
    }

    func updateNSView(_ nsView: ScreenshotDrawingView, context: Context) {}
}
