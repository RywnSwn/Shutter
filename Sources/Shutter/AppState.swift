import SwiftUI
import Combine

struct BlockedApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
}

struct BlockedSite: Codable, Identifiable, Hashable {
    var id: String { pattern.lowercased() }
    let pattern: String   // matched as case-insensitive substring against tab URLs
}

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon modifier mask: cmdKey | optionKey | controlKey | shiftKey

    static let `default` = Hotkey(
        keyCode: UInt32(0x01), // kVK_ANSI_S
        modifiers: UInt32(0x100 | 0x800 | 0x1000) // cmd | option | control
    )
}

/// Single source of truth. Watcher reads it, Enforcer acts on it, UI binds to it.
@MainActor
final class AppState: ObservableObject {
    @Published var isSecured: Bool = false
    @Published var blockedApps: [BlockedApp] = []
    @Published var blockedSites: [BlockedSite] = []
    @Published var hotkey: Hotkey = .default
    @Published var hasCompletedOnboarding: Bool = false
    @Published var showsPrivacyNotice: Bool = true

    private var cancellables = Set<AnyCancellable>()
    private let store = BlacklistStore()

    init() {
        let saved = store.load()
        self.blockedApps = saved.apps
        self.blockedSites = saved.sites
        self.hotkey = saved.hotkey
        self.hasCompletedOnboarding = saved.onboarded
        self.showsPrivacyNotice = saved.showsPrivacyNotice

        // Mirror state to disk whenever any saved field changes.
        let persist: () -> Void = { [weak self] in
            guard let self else { return }
            self.store.save(
                apps: self.blockedApps,
                sites: self.blockedSites,
                hotkey: self.hotkey,
                onboarded: self.hasCompletedOnboarding,
                showsPrivacyNotice: self.showsPrivacyNotice
            )
        }
        $blockedApps.dropFirst().sink { _ in persist() }.store(in: &cancellables)
        $blockedSites.dropFirst().sink { _ in persist() }.store(in: &cancellables)
        $hotkey.dropFirst().sink { _ in persist() }.store(in: &cancellables)
        $hasCompletedOnboarding.dropFirst().sink { _ in persist() }.store(in: &cancellables)
        $showsPrivacyNotice.dropFirst().sink { _ in persist() }.store(in: &cancellables)
    }
}
