import SwiftUI
import AppKit

struct MainWindow: View {
    @ObservedObject var state: AppState
    @State private var search: String = ""
    @State private var installed: [InstalledApp] = []
    @State private var selectedTab: Tab = .apps

    enum Tab: Hashable { case apps, websites, settings }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TabView(selection: $selectedTab) {
                AppPickerList(installed: filtered, selected: bindingSelected, search: $search)
                    .tabItem { Label("Apps", systemImage: "app.badge") }
                    .tag(Tab.apps)

                WebsitesTab(state: state)
                    .tabItem { Label("Websites", systemImage: "globe") }
                    .tag(Tab.websites)

                SettingsTab(state: state)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(Tab.settings)
            }
            .padding(.top, 6)
            Divider()
            footer
        }
        .frame(minWidth: 540, minHeight: 540)
        .onAppear { installed = InstalledAppsScanner.scan() }
    }

    private var filtered: [InstalledApp] {
        guard !search.isEmpty else { return installed }
        return installed.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var bindingSelected: Binding<Set<String>> {
        Binding(
            get: { Set(state.blockedApps.map(\.bundleIdentifier)) },
            set: { newIDs in
                // Preserve names for apps we already had; pull names from installed list for new ones.
                var byID: [String: BlockedApp] = [:]
                for app in state.blockedApps { byID[app.bundleIdentifier] = app }
                for app in installed { byID[app.bundleIdentifier] = BlockedApp(bundleIdentifier: app.bundleIdentifier, name: app.name) }
                state.blockedApps = newIDs.compactMap { byID[$0] }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            AppIconImage(size: 56)
                .shadow(color: Color.shutterAccent.opacity(0.30), radius: 12, y: 5)
            VStack(alignment: .leading, spacing: 6) {
                Text("Shutter")
                    .font(.system(size: 24, weight: .bold))
                StatusPill(isSecured: state.isSecured)
            }
            Spacer()
            Toggle("", isOn: $state.isSecured)
                .toggleStyle(.switch)
                .controlSize(.large)
                .tint(.shutterAccent)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(HeaderBackdrop())
    }

    private var footer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                Text("\(state.blockedApps.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.shutterAccent)
                Text(state.blockedApps.count == 1 ? "app" : "apps")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text("·").foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("\(state.blockedSites.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.shutterAccent)
                Text(state.blockedSites.count == 1 ? "site" : "sites")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                NSApp.keyWindow?.close()
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 70)
                    .padding(.vertical, 2)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.shutterAccent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

struct AppPickerList: View {
    let installed: [InstalledApp]
    @Binding var selected: Set<String>
    @Binding var search: String

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            countBar
            List(installed) { app in
                AppPickerRow(
                    app: app,
                    isSelected: selected.contains(app.bundleIdentifier),
                    onToggle: { toggle(app) }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("Search apps", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var countBar: some View {
        HStack(spacing: 6) {
            if selected.isEmpty {
                Text("None selected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(selected.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.shutterAccent)
                Text(selected.count == 1 ? "app selected" : "apps selected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !selected.isEmpty {
                Button("Clear") { selected.removeAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func toggle(_ app: InstalledApp) {
        if selected.contains(app.bundleIdentifier) {
            selected.remove(app.bundleIdentifier)
        } else {
            selected.insert(app.bundleIdentifier)
        }
    }
}

/// Single row in the app picker. Custom selection indicator (filled accent circle with
/// a check) plus a subtle hover/selected background. Replaces the stock SwiftUI checkbox
/// + plain row for a more designed feel.
private struct AppPickerRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                SelectionIndicator(isSelected: isSelected)
                AppIcon(url: app.url)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(app.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rowBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return Color.shutterAccent.opacity(0.10) }
        if hovering { return Color.primary.opacity(0.04) }
        return .clear
    }
}

/// Accent-filled circle with a check, replacing the stock SwiftUI checkbox.
private struct SelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .opacity(isSelected ? 0 : 1)

            Circle()
                .fill(Color.shutterAccent)
                .frame(width: 20, height: 20)
                .opacity(isSelected ? 1 : 0)

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .opacity(isSelected ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

struct SettingsTab: View {
    @ObservedObject var state: AppState
    @State private var hasPassword: Bool = KeychainStore.hasPassword
    @State private var hasRecoveryCode: Bool = KeychainStore.hasRecoveryCode
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hotkeySection
                startupSection
                passwordSection
                aboutSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Hotkey

    private var hotkeySection: some View {
        SettingsSection("Hotkey", icon: "keyboard") {
            SettingsRow(
                title: "Turn on from anywhere",
                subtitle: "This shortcut only enables Secure Mode. Turning it off is always a manual click — that's intentional."
            ) {
                HotkeyRecorder(hotkey: $state.hotkey)
            }
        }
    }

    // MARK: - Startup

    private var startupSection: some View {
        SettingsSection("Startup", icon: "power") {
            SettingsRow(
                title: "Launch Shutter at login",
                subtitle: "Shutter starts in the background when you log in to your Mac."
            ) {
                Toggle("", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        if LaunchAtLogin.setEnabled(newValue) {
                            launchAtLogin = newValue
                        } else {
                            launchAtLogin = LaunchAtLogin.isEnabled
                            let alert = NSAlert()
                            alert.messageText = "Couldn't change Launch at Login"
                            alert.informativeText = "This only works once Shutter is installed as a real .app in /Applications."
                            alert.runModal()
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.shutterAccent)
            }
        }
    }

    // MARK: - Password

    private var passwordSection: some View {
        SettingsSection("Password Lock", icon: "lock.shield") {
            if hasPassword {
                passwordStatusRow(set: true)
                Divider().opacity(0.3).padding(.leading, 14)
                SettingsRow(
                    title: "Change password",
                    subtitle: "Enter your current password, then set a new one."
                ) {
                    Button("Change…") {
                        PasswordPrompt.verify(reason: "Enter your current password.") { ok in
                            guard ok else { return }
                            PasswordPrompt.setNew { _ in
                                hasPassword = KeychainStore.hasPassword
                                hasRecoveryCode = KeychainStore.hasRecoveryCode
                            }
                        }
                    }
                }
                Divider().opacity(0.3).padding(.leading, 14)
                SettingsRow(
                    title: "Remove password",
                    subtitle: "Anyone with your Mac will be able to turn Secure Mode off."
                ) {
                    Button("Remove…") {
                        PasswordPrompt.verify(reason: "Enter your current password to remove it.") { ok in
                            guard ok else { return }
                            KeychainStore.clearPassword()
                            hasPassword = false
                            hasRecoveryCode = false
                        }
                    }
                }
                Divider().opacity(0.3).padding(.leading, 14)
                recoveryCodeRow
            } else {
                passwordStatusRow(set: false)
                Divider().opacity(0.3).padding(.leading, 14)
                SettingsRow(
                    title: "Set a password",
                    subtitle: "Required to turn Secure Mode off. A recovery code is generated automatically."
                ) {
                    Button {
                        PasswordPrompt.setNew { _ in
                            hasPassword = KeychainStore.hasPassword
                            hasRecoveryCode = KeychainStore.hasRecoveryCode
                        }
                    } label: {
                        Text("Set Password…")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.shutterAccent)
                    .controlSize(.small)
                }
            }
        }
    }

    private func passwordStatusRow(set: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((set ? Color.shutterAccent : Color.secondary).opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: set ? "lock.fill" : "lock.open")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(set ? Color.shutterAccent : .secondary)
            }
            Text(set
                 ? "Password is set — required to turn Secure Mode off."
                 : "No password set — anyone can turn Secure Mode off.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var recoveryCodeRow: some View {
        if hasRecoveryCode {
            SettingsRow(
                title: "Recovery code",
                subtitle: "Unlocks Shutter if you forget your password. View it to re-save somewhere safe."
            ) {
                Button("View Code…") {
                    PasswordPrompt.verify(reason: "Confirm your password to view the recovery code.") { ok in
                        guard ok, let code = KeychainStore.recoveryCode() else { return }
                        PasswordPrompt.showRecoveryCode(code, isInitialReveal: false)
                    }
                }
            }
        } else {
            SettingsRow(
                title: "Recovery code",
                subtitle: "Not yet generated. Create one in case you ever forget your password."
            ) {
                Button("Generate…") {
                    PasswordPrompt.verify(reason: "Confirm your password to generate a recovery code.") { ok in
                        guard ok else { return }
                        PasswordPrompt.generateAndShowRecoveryCode()
                        hasRecoveryCode = KeychainStore.hasRecoveryCode
                    }
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSection("About", icon: "info.circle") {
            HStack(spacing: 14) {
                AppIconImage(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shutter")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Version \(appVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Built around your privacy. All data stays on your Mac.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            Divider().opacity(0.3).padding(.leading, 14)
            SettingsRow(
                title: "Replay onboarding",
                subtitle: "Walk through the welcome screens again."
            ) {
                Button("Replay") {
                    state.hasCompletedOnboarding = false
                    NSApp.keyWindow?.close()
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Settings layout helpers

/// A settings section: small uppercase header with optional icon, then a Card containing rows.
private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content

    init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                SectionHeader(title: title)
            }
            .padding(.horizontal, 4)

            Card(padding: 0) {
                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

/// A single settings row: title + optional subtitle, with a trailing control (button, toggle, etc).
private struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct WebsitesTab: View {
    @ObservedObject var state: AppState
    @State private var newPattern: String = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            addBar
            if state.blockedSites.isEmpty {
                emptyState
            } else {
                siteList
            }
            footnote
        }
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("Add a domain (e.g. youtube.com)", text: $newPattern)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($addFieldFocused)
                    .onSubmit { add() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            Button {
                add()
            } label: {
                Text("Add")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 56)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.shutterAccent)
            .controlSize(.large)
            .disabled(trimmed.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Card(padding: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.shutterAccent.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "globe")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(Color.shutterAccent)
                    }
                    Text("No websites blocked yet")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add a domain above. While Secure Mode is on, any tab whose URL contains that text closes within ~2 seconds.")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 320)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var siteList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(state.blockedSites) { site in
                    SiteRow(pattern: site.pattern) {
                        state.blockedSites.removeAll { $0.id == site.id }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    private var footnote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Works in Safari, Chrome, Brave, Edge, and Arc.")
                Text("The first match per browser triggers a one-time macOS permission prompt.")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var trimmed: String {
        newPattern.trimmingCharacters(in: .whitespaces)
    }

    private func add() {
        let p = trimmed
        guard !p.isEmpty else { return }
        guard !state.blockedSites.contains(where: { $0.pattern.caseInsensitiveCompare(p) == .orderedSame }) else {
            newPattern = ""
            return
        }
        state.blockedSites.append(BlockedSite(pattern: p))
        newPattern = ""
        addFieldFocused = true
    }
}

/// Single row in the blocked-sites list. Reads as a chip — pill-shaped fill, accent dot,
/// trash button on the right that fades up on hover.
private struct SiteRow: View {
    let pattern: String
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.shutterAccent)
                .frame(width: 7, height: 7)
            Text(pattern)
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(hovering ? 0.08 : 0))
                    )
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0.55)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .onHover { hovering = $0 }
    }
}

struct AppIcon: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.image = NSWorkspace.shared.icon(forFile: url.path)
        v.imageScaling = .scaleProportionallyUpOrDown
        return v
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSWorkspace.shared.icon(forFile: url.path)
    }
}
