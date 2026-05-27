import SwiftUI
import AppKit
import Carbon.HIToolbox

/// SwiftUI wrapper. Click to record, press combo, releases when captured.
struct HotkeyRecorder: View {
    @Binding var hotkey: Hotkey
    @State private var isRecording: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            HotkeyCaptureView(isRecording: $isRecording) { captured in
                hotkey = captured
                isRecording = false
            }
            .frame(width: 180, height: 26)
            .overlay(
                Text(isRecording ? "Press keys…" : HotkeyFormatter.displayString(for: hotkey))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isRecording ? .secondary : .primary)
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
            )

            if isRecording {
                Button("Cancel") { isRecording = false }
            } else {
                Button("Record") { isRecording = true }
            }
        }
    }
}

/// NSView that becomes first responder while recording and captures the first valid combo.
private struct HotkeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (Hotkey) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let v = CaptureView()
        v.onCapture = { hk in
            onCapture(hk)
        }
        v.onCancel = {
            isRecording = false
        }
        return v
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.setRecording(isRecording)
    }

    final class CaptureView: NSView {
        var onCapture: ((Hotkey) -> Void)?
        var onCancel: (() -> Void)?
        private var recording = false

        override var acceptsFirstResponder: Bool { true }
        override func becomeFirstResponder() -> Bool { true }

        func setRecording(_ on: Bool) {
            recording = on
            if on { window?.makeFirstResponder(self) }
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }

            if Int(event.keyCode) == kVK_Escape {
                onCancel?()
                return
            }

            let mods = HotkeyFormatter.carbonModifiers(from: event.modifierFlags)
            // Require at least one modifier so a plain 'A' anywhere doesn't trigger.
            guard mods != 0 else {
                NSSound.beep()
                return
            }

            onCapture?(Hotkey(keyCode: UInt32(event.keyCode), modifiers: mods))
        }
    }
}
