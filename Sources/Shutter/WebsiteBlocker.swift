import AppKit

/// Closes browser tabs whose URL matches a pattern. Talks to browsers via AppleScript.
/// First run per-browser will trigger a macOS Automation permission prompt.
@MainActor
final class WebsiteBlocker {
    private let notifier: Notifier
    private var recentlyClosed: [String: Date] = [:]
    private let cooldown: TimeInterval = 3.0

    /// (display name shown in AppleScript, bundle ID, AppleScript dialect).
    private struct Browser {
        let appName: String
        let bundleID: String
        let dialect: Dialect
    }
    private enum Dialect { case safari, chromium }

    private let browsers: [Browser] = [
        Browser(appName: "Safari",          bundleID: "com.apple.Safari",            dialect: .safari),
        Browser(appName: "Google Chrome",   bundleID: "com.google.Chrome",           dialect: .chromium),
        Browser(appName: "Brave Browser",   bundleID: "com.brave.Browser",           dialect: .chromium),
        Browser(appName: "Microsoft Edge",  bundleID: "com.microsoft.edgemac",       dialect: .chromium),
        Browser(appName: "Arc",             bundleID: "company.thebrowser.Browser",  dialect: .chromium)
    ]

    init(notifier: Notifier) {
        self.notifier = notifier
    }

    /// Scan running browsers, close any tabs whose URL contains one of the patterns.
    func sweep(patterns: [String], runningApps: [NSRunningApplication]) {
        guard !patterns.isEmpty else { return }
        let runningIDs = Set(runningApps.compactMap(\.bundleIdentifier))

        for browser in browsers where runningIDs.contains(browser.bundleID) {
            let closed = runScript(for: browser, patterns: patterns)
            for url in closed { notifyOnce(url: url) }
        }
    }

    private func notifyOnce(url: String) {
        let now = Date()
        if let last = recentlyClosed[url], now.timeIntervalSince(last) < cooldown { return }
        recentlyClosed[url] = now
        let host = URL(string: url)?.host ?? url
        notifier.show(appName: host) // reuses the same popup style
    }

    private func runScript(for browser: Browser, patterns: [String]) -> [String] {
        let script = buildScript(for: browser, patterns: patterns)
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return [] }
        let descriptor = appleScript.executeAndReturnError(&error)

        if error != nil {
            // Most common reason: user denied automation permission. Don't spam — silent fail.
            return []
        }
        return extractStringList(from: descriptor)
    }

    private func extractStringList(from desc: NSAppleEventDescriptor) -> [String] {
        guard desc.numberOfItems > 0 else { return [] }
        var out: [String] = []
        for i in 1...desc.numberOfItems {
            if let s = desc.atIndex(i)?.stringValue { out.append(s) }
        }
        return out
    }

    private func buildScript(for browser: Browser, patterns: [String]) -> String {
        let conditions = patterns
            .map { "u contains \"\(escape($0))\"" }
            .joined(separator: " or ")

        switch browser.dialect {
        case .safari:
            return """
            tell application "\(browser.appName)"
                set closedURLs to {}
                try
                    repeat with w in windows
                        try
                            set tabsToClose to {}
                            repeat with t in tabs of w
                                set u to (URL of t) as string
                                if \(conditions) then
                                    set end of tabsToClose to t
                                    set end of closedURLs to u
                                end if
                            end repeat
                            repeat with t in tabsToClose
                                try
                                    close t
                                end try
                            end repeat
                        end try
                    end repeat
                end try
                return closedURLs
            end tell
            """

        case .chromium:
            return """
            tell application "\(browser.appName)"
                set closedURLs to {}
                try
                    repeat with w in windows
                        try
                            set toClose to {}
                            repeat with t in tabs of w
                                set u to URL of t
                                if \(conditions) then
                                    set end of toClose to t
                                    set end of closedURLs to u
                                end if
                            end repeat
                            repeat with t in toClose
                                try
                                    close t
                                end try
                            end repeat
                        end try
                    end repeat
                end try
                return closedURLs
            end tell
            """
        }
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
