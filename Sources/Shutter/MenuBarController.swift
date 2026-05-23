import AppKit
import SwiftUI
import Combine

/// Owns the menu bar icon + dropdown. Lets the user toggle secure mode and open the main window.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let state: AppState
    private let openMain: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private let menu = NSMenu()

    init(state: AppState, openMain: @escaping () -> Void) {
        self.state = state
        self.openMain = openMain
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        render() // initial paint

        // Whenever the live state changes, re-render. Single source of truth.
        Publishers.CombineLatest(state.$isSecured, state.$blockedApps)
            .sink { [weak self] _, _ in self?.render() }
            .store(in: &cancellables)
    }

    // MARK: - NSMenuDelegate

    // Belt-and-suspenders: always re-read state right before the menu opens.
    // Guarantees what you see is what the app actually believes, regardless of timing.
    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        Task { @MainActor in self.render() }
    }

    // MARK: - Render

    /// Single function. Reads `state.isSecured` now and paints icon + menu to match. Nothing else paints.
    private func render() {
        let secured = state.isSecured
        paintIcon(secured: secured)
        paintMenu(secured: secured, blockedCount: state.blockedApps.count)
    }

    private func paintIcon(secured: Bool) {
        guard let button = statusItem.button else { return }
        let symbol = secured ? "lock.fill" : "lock.open.fill"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: secured ? "Secured" : "Not secured")
        img?.isTemplate = true
        button.image = img
        button.toolTip = secured ? "Shutter — Secured" : "Shutter — Not Secured"
    }

    private func paintMenu(secured: Bool, blockedCount: Int) {
        menu.removeAllItems()

        let title = secured
            ? "Status: Secured (\(blockedCount) blocked)"
            : "Status: Not Secured"
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Secure Mode", action: #selector(toggleSecure), keyEquivalent: "s")
        toggle.target = self
        toggle.state = secured ? .on : .off
        menu.addItem(toggle)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Shutter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func toggleSecure() {
        // Turning ON: never requires auth. You can always make things MORE protected.
        if !state.isSecured {
            state.isSecured = true
            render()
            return
        }
        // Turning OFF: Touch ID first, password fallback. If neither is set up, just allow.
        BiometricUnlock.authenticate(reason: "Turn Secure Mode off") { [weak self] ok in
            guard let self, ok else { return }
            self.state.isSecured = false
            self.render()
        }
    }

    @objc private func openSettings() {
        openMain()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
