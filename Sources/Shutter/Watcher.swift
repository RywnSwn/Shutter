import AppKit
import Combine

/// Polls every 1.5s. Kills blacklisted apps and closes blacklisted browser tabs while secured.
@MainActor
final class Watcher {
    private weak var state: AppState?
    private let enforcer: Enforcer
    private let siteBlocker: WebsiteBlocker
    private var timer: Timer?

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
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

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
