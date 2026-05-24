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
        HStack(alignment: .center, spacing: 14) {
            AppIconImage(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shutter")
                    .font(.title2.bold())
                Text(state.isSecured ? "Secured — blocked apps will close instantly." : "Unsecured — flip the switch to enforce.")
                    .foregroundStyle(state.isSecured ? Color.shutterAccent : .secondary)
                    .font(.callout)
            }
            Spacer()
            Toggle("Secure", isOn: $state.isSecured)
                .toggleStyle(.switch)
                .controlSize(.large)
                .tint(.shutterAccent)
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Text("\(state.blockedApps.count) blocked")
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
            Button("Done") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }
}

struct AppPickerList: View {
    let installed: [InstalledApp]
    @Binding var selected: Set<String>
    @Binding var search: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search apps", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))

            List(installed) { app in
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { selected.contains(app.bundleIdentifier) },
                        set: { isOn in
                            if isOn { selected.insert(app.bundleIdentifier) }
                            else { selected.remove(app.bundleIdentifier) }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)

                    AppIcon(url: app.url)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(app.name)
                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selected.contains(app.bundleIdentifier) { selected.remove(app.bundleIdentifier) }
                    else { selected.insert(app.bundleIdentifier) }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct SettingsTab: View {
    @ObservedObject var state: AppState
    @State private var hasPassword: Bool = KeychainStore.hasPassword
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Secure Mode from anywhere")
                        Text("This hotkey only TURNS ON. Disabling is always a manual menu click.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HotkeyRecorder(hotkey: $state.hotkey)
                }
            }

            Section("Startup") {
                Toggle("Launch Shutter at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        if LaunchAtLogin.setEnabled(newValue) {
                            launchAtLogin = newValue
                        } else {
                            // Revert and warn — register fails when running from Xcode (not a real .app yet).
                            launchAtLogin = LaunchAtLogin.isEnabled
                            let alert = NSAlert()
                            alert.messageText = "Couldn't change Launch at Login"
                            alert.informativeText = "This only works once Shutter is installed as a real .app in /Applications."
                            alert.runModal()
                        }
                    }
                ))
            }

            Section("Password Lock") {
                if hasPassword {
                    HStack {
                        Image(systemName: "lock.fill").foregroundStyle(.green)
                        Text("Password is set — required to turn Secure Mode off.")
                        Spacer()
                    }
                    HStack {
                        Button("Change Password…") {
                            PasswordPrompt.verify(reason: "Enter your current password.") { ok in
                                guard ok else { return }
                                PasswordPrompt.setNew { _ in
                                    hasPassword = KeychainStore.hasPassword
                                }
                            }
                        }
                        Button("Remove Password…") {
                            PasswordPrompt.verify(reason: "Enter your current password to remove it.") { ok in
                                guard ok else { return }
                                KeychainStore.clearPassword()
                                hasPassword = false
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "lock.open").foregroundStyle(.secondary)
                        Text("No password set — anyone can turn Secure Mode off.")
                        Spacer()
                    }
                    Button("Set Password…") {
                        PasswordPrompt.setNew { _ in
                            hasPassword = KeychainStore.hasPassword
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 4)
    }
}

struct WebsitesTab: View {
    @ObservedObject var state: AppState
    @State private var newPattern: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Add a domain (e.g. youtube.com)", text: $newPattern)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                Button("Add") { add() }
                    .disabled(trimmed.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)

            if state.blockedSites.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No websites blocked yet")
                        .foregroundStyle(.secondary)
                    Text("Add a domain above. While Secure Mode is on, any tab whose URL contains that text closes within ~2 seconds.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.blockedSites) { site in
                        HStack {
                            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red.opacity(0.8))
                            Text(site.pattern)
                            Spacer()
                            Button(role: .destructive) {
                                state.blockedSites.removeAll { $0.id == site.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .listStyle(.inset)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Supported browsers: Safari, Chrome, Brave, Edge, Arc.")
                Text("First match per browser will trigger a one-time macOS permission prompt to control it.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
        }
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
