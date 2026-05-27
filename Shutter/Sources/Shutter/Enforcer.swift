import AppKit

/// Terminates the given running app and notifies the user. Knows nothing about state or UI logic.
@MainActor
final class Enforcer {
    private let notifier: Notifier

    /// Avoid spamming the popup for the same app while it's repeatedly trying to launch.
    private var recentlyBlocked: [String: Date] = [:]
    private let cooldown: TimeInterval = 3.0

    init(notifier: Notifier) {
        self.notifier = notifier
    }

    func kill(_ app: NSRunningApplication) {
        let name = app.localizedName ?? "App"
        let bid = app.bundleIdentifier ?? name

        app.forceTerminate()

        let now = Date()
        if let last = recentlyBlocked[bid], now.timeIntervalSince(last) < cooldown {
            return
        }
        recentlyBlocked[bid] = now
        notifier.show(appName: name)
    }
}
