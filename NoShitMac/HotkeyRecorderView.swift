import NoShitMacCore
import SwiftUI

struct HotkeyRecorderView: View {
    let label: String
    @Binding var binding: HotkeyBinding

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(isRecording ? "Press keys…" : binding.displayString) {
                startRecording()
            }
            .buttonStyle(.bordered)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                let mods = ModifierKey.from(nsFlags: event.modifierFlags.intersection([.command, .option, .control, .shift]))
                if !mods.isEmpty {
                    binding = HotkeyBinding(keyCode: event.keyCode, modifiers: mods)
                    stopRecording()
                    return nil
                }
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
