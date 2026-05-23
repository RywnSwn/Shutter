import AppKit

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let url: URL
}

/// One-shot scan of /Applications and ~/Applications for installed .app bundles.
enum InstalledAppsScanner {
    static func scan() -> [InstalledApp] {
        let roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for root in roots {
            guard let items = try? FileManager.default.contentsOfDirectory(at: root,
                                                                            includingPropertiesForKeys: nil) else { continue }
            for url in items where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bid = bundle.bundleIdentifier,
                      !seen.contains(bid) else { continue }
                seen.insert(bid)
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                apps.append(InstalledApp(bundleIdentifier: bid, name: name, url: url))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
