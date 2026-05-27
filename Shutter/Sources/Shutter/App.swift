import AppKit
import SwiftUI
import Combine

// Entry point. Builds the object graph, owns long-lived references, manages windows.
// All app objects live here for the lifetime of the process — nothing tries to outlive its owner.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var state: AppState!
    private var notifier: Notifier!
    private var enforcer: Enforcer!
    private var siteBlocker: WebsiteBlocker!
    private var watcher: Watcher!
    private var menuBar: MenuBarController!
    private var hotkey: GlobalHotkey!
    private var cancellables = Set<AnyCancellable>()

    private var mainWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        state = AppState()
        notifier = Notifier()
        notifier.isEnabled = state.showsPrivacyNotice
        enforcer = Enforcer(notifier: notifier)
        siteBlocker = WebsiteBlocker(notifier: notifier)
        watcher = Watcher(state: state, enforcer: enforcer, siteBlocker: siteBlocker)
        watcher.start()

        // Keep the live Notifier in sync with the Settings toggle.
        state.$showsPrivacyNotice
            .sink { [weak self] enabled in self?.notifier.isEnabled = enabled }
            .store(in: &cancellables)

        menuBar = MenuBarController(state: state) { [weak self] in
            self?.showMainWindow()
        }

        // Global hotkey: enables Secure Mode from anywhere, regardless of focused app.
        // Intentionally one-way: never disables — that must be a deliberate menu click.
        hotkey = GlobalHotkey()
        applyHotkey(state.hotkey)
        state.$hotkey
            .dropFirst()
            .sink { [weak self] hk in self?.applyHotkey(hk) }
            .store(in: &cancellables)

        if !state.hasCompletedOnboarding {
            showOnboarding()
        } else if !Self.wasLaunchedAtLogin {
            // Double-clicking the app (vs. login-launch in the background) opens Settings.
            showMainWindow()
        }

        // Re-show onboarding if the user clicks "Replay" in Settings (which flips the flag).
        state.$hasCompletedOnboarding
            .dropFirst()
            .sink { [weak self] completed in
                guard !completed, self?.onboardingWindow == nil else { return }
                self?.showOnboarding()
            }
            .store(in: &cancellables)

        // Second-launch handoff: another Shutter process posts this when the user double-clicks
        // the app while we're already running. Open Settings on the running instance.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.rywn.shutter.showSettings"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.showMainWindow() }
        }
    }

    /// Triggered when the user clicks the app while it's already running (Finder reopen,
    /// dock click on regular apps, etc). We're accessory-mode so this is the only "reopen"
    /// path we get for free. Returns false so AppKit doesn't try its own untitled-window logic.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    /// Heuristic for "did launchd start us at login vs. did the user double-click us?"
    /// At-login launches arrive with `keyAELaunchedAsLogInItem = true` in the kAEOpenApplication event.
    private static var wasLaunchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        let key = AEKeyword(0x6c676974) // 'lgit' = keyAELaunchedAsLogInItem
        return event.paramDescriptor(forKeyword: key)?.booleanValue == true
    }

    /// Minimal app menu so standard text-editing shortcuts (Cmd+C/V/X/A/Z) work in text fields.
    /// Accessory apps don't get a menu bar from AppKit automatically, and without the Edit menu
    /// installed there's no key-equivalent dispatch — paste into "Add a domain" silently fails.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Shutter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func applyHotkey(_ hk: Hotkey) {
        hotkey.register(keyCode: hk.keyCode, modifiers: hk.modifiers) { [weak self] in
            guard let self else { return }
            if !self.state.isSecured { self.state.isSecured = true }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Stay alive in the menu bar even when all windows are closed.
    }

    private func showMainWindow() {
        if let win = mainWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: MainWindow(state: state))
        let win = NSWindow(contentViewController: host)
        win.title = "Shutter"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 560, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        mainWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboarding() {
        let host = NSHostingController(rootView: OnboardingView(state: state) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        })
        let win = NSWindow(contentViewController: host)
        win.title = "Welcome"
        win.styleMask = [.titled, .closable]
        win.setContentSize(NSSize(width: 560, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        onboardingWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Closing the onboarding window (X button or "Get Started") counts as completed —
    // otherwise users who dismiss it get the slideshow on every launch.
    func windowWillClose(_ notification: Notification) {
        guard let win = notification.object as? NSWindow, win === onboardingWindow else { return }
        if !state.hasCompletedOnboarding {
            state.hasCompletedOnboarding = true
        }
        onboardingWindow = nil
    }
}

@main
enum ShutterMain {
    static func main() {
        // Single-instance guard: if another Shutter is already running, surface it and exit.
        let me = ProcessInfo.processInfo.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? "com.rywn.shutter"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me }
        if let existing = others.first {
            // Tell the running instance to surface Settings before we exit.
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("com.rywn.shutter.showSettings"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            existing.activate(options: [.activateAllWindows])
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // menu bar app, no dock icon
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
