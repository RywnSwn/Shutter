import AppKit
import SwiftUI
import Combine

/// Owns the menu bar icon + the popover that drops down when it's clicked.
/// Left-click toggles the popover. Right-click shows a small context menu for Quit.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let state: AppState
    private let openMain: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private let popover = NSPopover()
    private var eventMonitor: Any?

    init(state: AppState, openMain: @escaping () -> Void) {
        self.state = state
        self.openMain = openMain
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        paintIcon(secured: state.isSecured)

        // Repaint icon whenever Secure Mode flips.
        state.$isSecured
            .sink { [weak self] secured in self?.paintIcon(secured: secured) }
            .store(in: &cancellables)
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        // Rebuild content each open so the SwiftUI view always reflects current state.
        // Holding one NSHostingController for the popover's lifetime caused stale toggle
        // visuals after async actions (biometric cancel) and layout jumps on reopen.
        let controller = NSHostingController(
            rootView: MenuBarPopover(
                state: state,
                onOpenSettings: { [weak self] in
                    self?.closePopover()
                    self?.openMain()
                },
                onQuit: { NSApp.terminate(nil) },
                onToggleRequested: { [weak self] in self?.handleToggle() }
            )
        )
        // Measure the SwiftUI view's actual fitting size and use that as the popover
        // frame. .intrinsicContentSize sizingOption reported back inflated heights;
        // fittingSize gives us exactly what SwiftUI laid out.
        popover.contentViewController = controller
        controller.view.layoutSubtreeIfNeeded()
        popover.contentSize = controller.view.fittingSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        startMonitoringOutsideClicks()
    }

    private func closePopover() {
        popover.performClose(nil)
        stopMonitoringOutsideClicks()
    }

    // Catches every dismissal path: programmatic close, outside-click auto-dismiss,
    // app deactivation, etc. SwiftUI's onHover(false) won't fire when the view's window
    // disappears, so we reset the cursor here to avoid a sticky pointing-hand.
    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            NSCursor.arrow.set()
            self.stopMonitoringOutsideClicks()
        }
    }

    /// `.transient` already auto-dismisses on outside clicks, but a global monitor
    /// catches edge cases (clicks on other status items, fast switches) more reliably.
    private func startMonitoringOutsideClicks() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func stopMonitoringOutsideClicks() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Shutter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Detach so the next left-click opens the popover instead of the menu.
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    // MARK: - Actions

    /// Turning ON is free. Turning OFF requires Touch ID / password if one is set.
    private func handleToggle() {
        if !state.isSecured {
            state.isSecured = true
            return
        }
        BiometricUnlock.authenticate(reason: "Turn Secure Mode off") { [weak self] ok in
            guard let self, ok else { return }
            self.state.isSecured = false
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Icon

    private func paintIcon(secured: Bool) {
        guard let button = statusItem.button else { return }
        button.image = menuBarTemplateIcon()
        // Full opacity when Secured, dimmed when off — gives a quick visual read of state.
        button.alphaValue = secured ? 1.0 : 0.55
        button.toolTip = secured ? "Shutter — Secured" : "Shutter — Not Secured"
    }

    /// Flat monochrome template icon: a rounded square outline containing 5 horizontal
    /// bars (the "shutter slats" motif from the app icon). Drawn as a template so macOS
    /// auto-tints it for light/dark menu bars.
    private func menuBarTemplateIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // Rounded square outline.
            let outerRect = rect.insetBy(dx: 1.25, dy: 1.25)
            let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 3.5, yRadius: 3.5)
            outerPath.lineWidth = 1.4
            outerPath.stroke()

            // 5 horizontal slats, evenly distributed inside the box.
            let slatCount = 5
            let slatHeight: CGFloat = 1.3
            let slatInsetX: CGFloat = 4
            let topY: CGFloat = 4
            let bottomY: CGFloat = 14
            let innerHeight = bottomY - topY
            let totalGap = innerHeight - CGFloat(slatCount) * slatHeight
            let gap = totalGap / CGFloat(slatCount + 1)

            for i in 0..<slatCount {
                let y = topY + gap + CGFloat(i) * (slatHeight + gap)
                let slatRect = NSRect(
                    x: rect.minX + slatInsetX,
                    y: y,
                    width: rect.width - slatInsetX * 2,
                    height: slatHeight
                )
                NSBezierPath(roundedRect: slatRect, xRadius: 0.5, yRadius: 0.5).fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - Popover content

struct MenuBarPopover: View {
    @ObservedObject var state: AppState
    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    var onToggleRequested: () -> Void

    @State private var emergencyArmed = false
    @State private var emergencyResetTask: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toggleRow
            Divider()
            emergencyRow
            Divider()
            footer
            Divider().opacity(0.4)
            MadeByRyan()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconImage(size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Shutter")
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.isSecured ? Color.shutterAccent : Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                    Text(state.isSecured ? "Secured" : "Not secured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
    }

    private var toggleRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Secure Mode")
                    .font(.system(size: 13, weight: .medium))
                Text("\(state.blockedApps.count) apps · \(state.blockedSites.count) sites")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Same pattern as the main window header: visual is constant-bound so the
            // switch position purely follows state.isSecured. An invisible button handles
            // the tap → auth check → state update. No animated flip-then-revert if the
            // user cancels biometric.
            Toggle("", isOn: .constant(state.isSecured))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.large)
                .tint(.shutterAccent)
                .allowsHitTesting(false)
                .overlay(
                    Button(action: onToggleRequested) {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                )
        }
        .padding(14)
    }

    /// Panic button: first tap arms (button turns red, "Tap again to confirm"); a second
    /// tap within 3 seconds quits every regular running app and locks the Mac. The arm state
    /// auto-clears so an accidental brush doesn't leave it primed.
    private var emergencyRow: some View {
        Button {
            if emergencyArmed {
                emergencyResetTask?.cancel()
                emergencyResetTask = nil
                emergencyArmed = false
                EmergencyAction.execute()
            } else {
                emergencyArmed = true
                emergencyResetTask?.cancel()
                let task = DispatchWorkItem { emergencyArmed = false }
                emergencyResetTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: emergencyArmed ? "exclamationmark.triangle.fill" : "bolt.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(emergencyArmed ? "Tap again to confirm" : "Emergency: close apps & lock")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.red.opacity(emergencyArmed ? 0.20 : 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.red.opacity(emergencyArmed ? 0.55 : 0.20), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.15), value: emergencyArmed)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            FooterButton(title: "Settings", systemImage: "gearshape", action: onOpenSettings)
            Divider().frame(height: 22)
            FooterButton(title: "Quit", systemImage: "power", action: onQuit)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
}

/// Footer row button with a native-feeling hover state: pointing-hand cursor + a faint
/// background fill while the pointer is inside. Used for Settings and Quit.
private struct FooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.08) : Color.clear)
        .onHover { isHovering in
            hovering = isHovering
            if isHovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

/// Panic action wired to the emergency button. Sends a graceful `terminate` to every
/// regular running app (skips background/system processes and Shutter itself), then
/// locks the screen via CGSession -suspend. The Mac stays powered on — the user logs
/// back in to resume.
@MainActor
enum EmergencyAction {
    static func execute() {
        let me = Bundle.main.bundleIdentifier
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.bundleIdentifier != me else { continue }
            app.terminate()
        }
        let lock = Process()
        lock.launchPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        lock.arguments = ["-suspend"]
        try? lock.run()
    }
}
