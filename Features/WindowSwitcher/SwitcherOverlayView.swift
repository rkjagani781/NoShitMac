import SwiftUI

struct SwitcherOverlayView: View {
    let windows: [WindowInfo]
    let selectedIndex: Int
    let thumbnails: [CGWindowID: NSImage]

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]

    var body: some View {
        VStack(spacing: 16) {
            Text("Window Switcher")
                .font(.headline)
                .foregroundStyle(.secondary)

            if windows.isEmpty {
                Text("No windows found")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(140))], spacing: 16) {
                        ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                            WindowTile(
                                window: window,
                                thumbnail: thumbnails[window.id],
                                isSelected: index == selectedIndex
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Text("Tab / Shift+Tab to cycle · Release ⌥ to switch")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .padding(40)
    }
}

private struct WindowTile: View {
    let window: WindowInfo
    let thumbnail: NSImage?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 160, height: 100)

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            Text(window.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 160)

            HStack(spacing: 4) {
                Text(window.ownerName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if window.isMinimized {
                    Text("minimized")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if !window.isOnScreen {
                    Text("other space")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}
