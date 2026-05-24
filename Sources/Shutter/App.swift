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
        state = AppState()
        notifier = Notifier()
        enforcer = Enforcer(notifier: notifier)
        siteBlocker = WebsiteBlocker(notifier: notifier)
        watcher = Watcher(state: state, enforcer: enforcer, siteBlocker: siteBlocker)
        watcher.start()

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
        }

        // Re-show onboarding if the user clicks "Replay" in Settings (which flips the flag).
        state.$hasCompletedOnboarding
            .dropFirst()
            .sink { [weak self] completed in
                guard !completed, self?.onboardingWindow == nil else { return }
                self?.showOnboarding()
            }
            .store(in: &cancellables)
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
