import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var state: AppState
    var onDone: () -> Void

    @State private var page: Int = 0
    @State private var installed: [InstalledApp] = []
    @State private var search: String = ""
    @State private var hasPassword: Bool = KeychainStore.hasPassword

    private let totalPages = 5

    var body: some View {
        ZStack {
            HeroBackground()

            VStack(spacing: 0) {
                pageContent
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.3)
                footer
            }
        }
        .frame(width: 580, height: 540)
        .onAppear { installed = InstalledAppsScanner.scan() }
    }

    // MARK: - Page router

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0: welcome
        case 1: privacy
        case 2: picker
        case 3: password
        default: ready
        }
    }

    // MARK: - Pages

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            OnboardingHero.Welcome()
            Text("Meet Shutter")
                .font(.system(size: 34, weight: .bold))
            Text("Keep certain apps out of sight when someone else is on your Mac. Flip Secure Mode on, and they close instantly the moment they're opened.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
                .padding(.horizontal, 50)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var privacy: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            OnboardingHero.Privacy()
            Text("Private by design")
                .font(.system(size: 30, weight: .bold))
            Text("Shutter is built for one Mac. Yours.")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

            Card {
                VStack(spacing: 14) {
                    trustRow(icon: "wifi.slash", title: "Never connects to the internet", body: "No telemetry, no analytics, no servers.")
                    Divider().opacity(0.3)
                    trustRow(icon: "person.crop.circle.badge.xmark", title: "No account required", body: "Nothing to sign up for, nothing to sync.")
                    Divider().opacity(0.3)
                    trustRow(icon: "externaldrive.badge.checkmark", title: "Stored in your Keychain", body: "Your blocklist and password live where Mac stores its own.")
                }
            }
            .frame(maxWidth: 420)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func trustRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.shutterAccent)
                .frame(width: 28, height: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(body).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pick what to keep private")
                    .font(.system(size: 22, weight: .bold))
                Text("Choose any apps you'd rather not have a stranger stumble into. You can always change this later.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            AppPickerList(installed: filtered, selected: bindingSelected, search: $search)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }

    private var password: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            OnboardingHero.Password()
            Text(hasPassword ? "Password set" : "Lock it down")
                .font(.system(size: 30, weight: .bold))
            Text(hasPassword
                 ? "You're protected. You can change or remove your password anytime from Settings."
                 : "A password keeps Secure Mode locked when it's on. Without one, anyone using your Mac can turn it off. This is optional — but recommended.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
                .padding(.horizontal, 50)
                .fixedSize(horizontal: false, vertical: true)

            if !hasPassword {
                Button {
                    PasswordPrompt.setNew { _ in
                        hasPassword = KeychainStore.hasPassword
                    }
                } label: {
                    Text("Set a password")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minWidth: 180)
                        .padding(.vertical, 4)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(.shutterAccent)
                .padding(.top, 4)
            } else {
                Label("Recovery code saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.top, 4)
            }
            Spacer()
        }
    }

    private var ready: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            OnboardingHero.Ready()
            Text("You're ready")
                .font(.system(size: 34, weight: .bold))
            Text("Shutter is in your menu bar. Click the lock icon anytime to turn Secure Mode on or off.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
                .padding(.horizontal, 50)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                if page > 0 {
                    Button("Back") { advance(by: -1) }
                        .buttonStyle(.borderless)
                }
                Spacer()
                PageDots(current: page, total: totalPages)
                Spacer()
                Button {
                    if page < totalPages - 1 {
                        advance(by: 1)
                    } else {
                        state.hasCompletedOnboarding = true
                        onDone()
                    }
                } label: {
                    Text(primaryLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(minWidth: 80)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(.shutterAccent)
                .keyboardShortcut(.defaultAction)
            }
            MadeByRyan()
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func advance(by delta: Int) {
        withAnimation(.easeInOut(duration: 0.28)) {
            page = max(0, min(totalPages - 1, page + delta))
        }
    }

    /// Skip on the password page when no password is set; Get Started on the last page; Continue otherwise.
    private var primaryLabel: String {
        if page == totalPages - 1 { return "Open Shutter" }
        if page == 3 && !hasPassword { return "Skip for now" }
        return "Continue"
    }

    // MARK: - Helpers

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

// MARK: - Page dots

/// Small filled-circle progress indicator. Current page is the accent color and slightly larger.
private struct PageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.shutterAccent : Color.secondary.opacity(0.35))
                    .frame(width: i == current ? 8 : 6, height: i == current ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}
