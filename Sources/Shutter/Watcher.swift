import AppKit
import Combine

/// Two layers of enforcement while secured:
///   1. A launch observer kills blacklisted apps the instant they appear (sub-second).
///   2. A 1.5s poll catches anything the observer missed and sweeps browser tabs.
@MainActor
final class Watcher {
    private weak var state: AppState?
    private let enforcer: Enforcer
    private let siteBlocker: WebsiteBlocker
    private var timer: Timer?
    private var launchObserver: NSObjectProtocol?

    init(state: AppState, enforcer: Enforcer, siteBlocker: WebsiteBlocker) {
        self.state = state
        self.enforcer = enforcer
        self.siteBlocker = siteBlocker
    }

    func start() {
        guard timer == nil else { return }
        // Slightly longer interval — AppleScript round-trips per browser add up if there are several.
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        // Instant-kill: fires the moment any app finishes launching, anywhere on the system.
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleLaunch(notification) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            launchObserver = nil
        }
    }

    /// Instant path: a single app just launched — kill it if it's on the blacklist.
    private func handleLaunch(_ notification: Notification) {
        guard let state, state.isSecured, !state.blockedApps.isEmpty else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bid = app.bundleIdentifier,
              bid != Bundle.main.bundleIdentifier else { return }
        let blockedIDs = Set(state.blockedApps.map(\.bundleIdentifier))
        guard blockedIDs.contains(bid) else { return }
        enforcer.kill(app)
    }

    /// Fallback poll: catches anything already running when Secure Mode flipped on,
    /// and handles browser tab sweeping which has no per-event hook.
    private func tick() {
        guard let state, state.isSecured else { return }
        let running = NSWorkspace.shared.runningApplications

        // 1. Kill blacklisted apps.
        if !state.blockedApps.isEmpty {
            let blockedIDs = Set(state.blockedApps.map(\.bundleIdentifier))
            for app in running {
                guard let bid = app.bundleIdentifier, blockedIDs.contains(bid) else { continue }
                if bid == Bundle.main.bundleIdentifier { continue }
                enforcer.kill(app)
            }
        }

        // 2. Close blacklisted browser tabs.
        if !state.blockedSites.isEmpty {
            siteBlocker.sweep(patterns: state.blockedSites.map(\.pattern), runningApps: running)
        }
    }
}
