import Foundation

/// Reads & writes saved state to ~/Library/Application Support/Shutter/config.json.
struct BlacklistStore {
    struct Saved: Codable {
        var apps: [BlockedApp] = []
        var sites: [BlockedSite] = []
        var hotkey: Hotkey = .default
        var onboarded: Bool = false
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Shutter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    func load() -> Saved {
        guard let data = try? Data(contentsOf: fileURL) else { return Saved() }
        // Decoder tolerates missing fields because Saved has defaults — old configs upgrade cleanly.
        let decoder = JSONDecoder()
        return (try? decoder.decode(Saved.self, from: data)) ?? Saved()
    }

    func save(apps: [BlockedApp], sites: [BlockedSite], hotkey: Hotkey, onboarded: Bool) {
        let payload = Saved(apps: apps, sites: sites, hotkey: hotkey, onboarded: onboarded)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
