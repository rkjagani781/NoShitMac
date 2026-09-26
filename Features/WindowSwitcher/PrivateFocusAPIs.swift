import ApplicationServices
import CoreGraphics
import Foundation

/// Private WindowServer focus helpers used by AltTab / Hammerspoon / yabai.
/// Public APIs cannot focus a specific window across Spaces or secondary displays reliably.

private let kCPSUserGenerated: UInt32 = 0x200

@_silgen_name("GetProcessForPID")
private func NSMGetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

@_silgen_name("_SLPSSetFrontProcessWithOptions")
private func _SLPSSetFrontProcessWithOptions(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ wid: CGWindowID,
    _ mode: UInt32
) -> CGError

@_silgen_name("SLPSPostEventRecordTo")
private func SLPSPostEventRecordTo(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ bytes: UnsafeMutableRawPointer
) -> CGError

enum PrivateFocusAPIs {
    /// Focus a specific window by CGWindowID — switches Space/display like AltTab.
    @discardableResult
    static func focusWindow(pid: pid_t, windowID: CGWindowID) -> Bool {
        var psn = ProcessSerialNumber()
        guard NSMGetProcessForPID(pid, &psn) == noErr else { return false }

        let frontStatus = _SLPSSetFrontProcessWithOptions(&psn, windowID, kCPSUserGenerated)
        makeKeyWindow(psn: &psn, windowID: windowID)
        return frontStatus == .success
    }

    /// Ported from Hammerspoon / AltTab — marks the target CG window as key.
    private static func makeKeyWindow(psn: inout ProcessSerialNumber, windowID: CGWindowID) {
        var bytes1 = [UInt8](repeating: 0, count: 0xf8)
        bytes1[0x04] = 0xF8
        bytes1[0x08] = 0x01
        bytes1[0x3a] = 0x10

        var bytes2 = [UInt8](repeating: 0, count: 0xf8)
        bytes2[0x04] = 0xF8
        bytes2[0x08] = 0x02
        bytes2[0x3a] = 0x10

        withUnsafeBytes(of: windowID.littleEndian) { widBytes in
            for i in 0..<MemoryLayout<CGWindowID>.size {
                bytes1[0x3c + i] = widBytes[i]
                bytes2[0x3c + i] = widBytes[i]
            }
        }
        for i in 0x20..<0x30 {
            bytes1[i] = 0xFF
            bytes2[i] = 0xFF
        }

        [bytes1, bytes2].forEach { bytes in
            var mutable = bytes
            mutable.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress else { return }
                _ = SLPSPostEventRecordTo(&psn, base)
            }
        }
    }
}
