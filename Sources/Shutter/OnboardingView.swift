import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var state: AppState
    var onDone: () -> Void

    @State private var page: Int = 0
    @State private var installed: [InstalledApp] = []
    @State private var search: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: welcome
                case 1: picker
                default: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            footer
        }
        .frame(width: 560, height: 520)
        .onAppear { installed = InstalledAppsScanner.scan() }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Welcome to Shutter")
                .font(.largeTitle.bold())
            Text("Pick the apps you want to keep private.\nWhen Secure mode is on, they'll close instantly if anyone tries to open them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose apps to block")
                .font(.title2.bold())
                .padding(.horizontal, 16)
                .padding(.top, 16)
            Text("You can change this list anytime from Settings.")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            AppPickerList(installed: filtered, selected: bindingSelected, search: $search)
        }
    }

    private var ready: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.largeTitle.bold())
            Text("Shutter lives in your menu bar.\nClick the lock icon to toggle Secure mode anytime.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            if page > 0 {
                Button("Back") { page -= 1 }
            }
            Spacer()
            Text("\(page + 1) of 3")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
            Button(page < 2 ? "Continue" : "Get Started") {
                if page < 2 { page += 1 }
                else {
                    state.hasCompletedOnboarding = true
                    onDone()
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    private var filtered: [InstalledApp] {
        guard !search.isEmpty else { return installed }
        return installed.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var bindingSelected: Binding<Set<String>> {
        Binding(
            get: { Set(state.blockedApps.map(\.bundleIdentifier)) },
            set: { newIDs in
                var byID: [String: BlockedApp] = [:]
                for app in state.blockedApps { byID[app.bundleIdentifier] = app }
                for app in installed { byID[app.bundleIdentifier] = BlockedApp(bundleIdentifier: app.bundleIdentifier, name: app.name) }
                state.blockedApps = newIDs.compactMap { byID[$0] }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        )
    }
}
