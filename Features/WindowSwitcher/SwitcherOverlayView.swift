import SwiftUI

struct SwitcherOverlayView: View {
    let windows: [WindowInfo]
    let selectedIndex: Int
    let thumbnails: [CGWindowID: NSImage]
    let onHover: (Int) -> Void
    let onSelect: (Int) -> Void

    private var usesTwoRows: Bool { windows.count > 6 }

    var body: some View {
        VStack(spacing: 12) {
            if windows.isEmpty {
                Text("No windows found")
                    .foregroundStyle(.secondary)
                    .padding()
            } else if usesTwoRows {
                let items = Array(windows.enumerated())
                let mid = (items.count + 1) / 2
                windowRow(Array(items.prefix(mid)))
                windowRow(Array(items.suffix(from: mid)))
            } else {
                windowRow(Array(windows.enumerated()))
            }

            Text("Tab / ← → to cycle · Click to switch · Esc cancel · Release ⌥ to switch")
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
        .padding(24)
    }

    private func windowRow(_ items: [(offset: Int, element: WindowInfo)]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(items, id: \.element.id) { index, window in
                        WindowTile(
                            window: window,
                            thumbnail: thumbnails[window.id],
                            isSelected: index == selectedIndex
                        )
                        .id(window.id)
                        .onHover { hovering in
                            if hovering { onHover(index) }
                        }
                        .onTapGesture { onSelect(index) }
                    }
                }
                .padding(.horizontal, 12)
            }
            .onAppear {
                scrollToSelection(using: proxy, animated: false)
            }
            .onChange(of: selectedIndex) {
                scrollToSelection(using: proxy, animated: true)
            }
        }
        .frame(height: 160)
    }

    private func scrollToSelection(using proxy: ScrollViewProxy, animated: Bool) {
        guard windows.indices.contains(selectedIndex) else { return }
        let action = {
            proxy.scrollTo(windows[selectedIndex].id, anchor: .center)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.12), action)
        } else {
            action()
        }
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
                    .fill(Color.black.opacity(0.25))
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
                if !window.screenName.isEmpty {
                    Text("· \(window.screenName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
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
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .contentShape(Rectangle())
    }
}
