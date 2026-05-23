import AppKit
import SwiftUI

/// Floating top-right popup that auto-dismisses. Doesn't need bundle/entitlements like UNUserNotificationCenter would.
@MainActor
final class Notifier {
    private var activeWindows: [NSWindow] = []

    func show(appName: String) {
        let message = "For privacy reasons, \(appName) will not be opened."
        let size = NSSize(width: 360, height: 90)

        let hosting = NSHostingView(rootView: PopupView(message: message, width: size.width, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isFloatingPanel = true
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.contentView = hosting
        window.setContentSize(size)
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position top-right of the main screen, stacked below any existing popups.
        if let screen = NSScreen.main {
            let margin: CGFloat = 16
            let stackOffset = CGFloat(activeWindows.count) * (size.height + 8)
            let x = screen.visibleFrame.maxX - size.width - margin
            let y = screen.visibleFrame.maxY - size.height - margin - stackOffset
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.alphaValue = 0
        window.orderFrontRegardless()
        activeWindows.append(window)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self, weak window] in
            guard let window else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
                self?.activeWindows.removeAll { $0 === window }
            })
        }
    }
}

private struct PopupView: View {
    let message: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shutter")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: width, height: height, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 4)
        )
    }
}
