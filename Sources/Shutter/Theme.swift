import SwiftUI
import AppKit

extension Color {
    /// Warm orange pulled from the app icon. Used for Secure Mode accents.
    static let shutterAccent = Color(red: 0.91, green: 0.52, blue: 0.18)
}

/// Renders the bundled app icon at a fixed pixel size.
/// Falls back to a generic lock symbol if the icon can't be resolved (e.g. running from Xcode without a bundled icns).
struct AppIconImage: View {
    var size: CGFloat = 64

    var body: some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: size * 0.75))
                .foregroundStyle(Color.shutterAccent)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Hero background

/// Soft tinted gradient backdrop for "hero" surfaces (onboarding, top of main window).
/// Two-layer composition: a top-down linear wash plus a radial pop near the top to give
/// the eye a focal point without competing with the foreground content.
struct HeroBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.shutterAccent.opacity(0.10),
                    Color.shutterAccent.opacity(0.02),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.shutterAccent.opacity(0.18), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 280
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Card

/// Subtle grouped container — soft background fill, hairline border, rounded corners.
/// Use to give a set of related rows visual cohesion vs. floating in empty space.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 14
    let content: Content

    init(padding: CGFloat = 16, cornerRadius: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}

// MARK: - Status pill

/// Compact rounded badge indicating Secure Mode state. Accent-tinted when secured,
/// neutral when not. Used in the main window header and anywhere else status needs
/// to read at a glance.
struct StatusPill: View {
    let isSecured: Bool
    var size: Size = .regular

    enum Size { case regular, small }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isSecured ? Color.shutterAccent : Color.secondary.opacity(0.55))
                .frame(width: dotSize, height: dotSize)
            Text(isSecured ? "Secured" : "Not secured")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(isSecured ? Color.shutterAccent : Color.secondary)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule()
                .fill(isSecured ? Color.shutterAccent.opacity(0.13) : Color.secondary.opacity(0.10))
        )
    }

    private var dotSize: CGFloat { size == .regular ? 7 : 6 }
    private var fontSize: CGFloat { size == .regular ? 12 : 11 }
    private var horizontalPadding: CGFloat { size == .regular ? 10 : 8 }
    private var verticalPadding: CGFloat { size == .regular ? 4 : 3 }
}

// MARK: - Section header

/// Compact uppercase label used to introduce a group of related rows or controls.
/// Replaces the stock SwiftUI Form section style for custom layouts.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Header backdrop

/// Subtle accent-tinted wash used at the top of windows. Lighter than HeroBackground —
/// enough to signal "this is the header zone" without dominating.
struct HeaderBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [Color.shutterAccent.opacity(0.08), Color.clear],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Hero illustration scenes

/// Composed visual scenes used at the top of each onboarding page. Each one layers
/// SF Symbols + glows + gradients to read as a designed illustration rather than a
/// single placeholder icon.
enum OnboardingHero {

    /// App icon centered on a soft glowing aura.
    struct Welcome: View {
        var body: some View {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.shutterAccent.opacity(0.35), .clear],
                            center: .center, startRadius: 10, endRadius: 110
                        )
                    )
                    .frame(width: 240, height: 240)
                    .blur(radius: 18)
                AppIconImage(size: 112)
                    .shadow(color: Color.shutterAccent.opacity(0.45), radius: 22, y: 10)
            }
            .frame(height: 220)
        }
    }

    /// A Mac with a lock-shield badge floating on its corner.
    struct Privacy: View {
        var body: some View {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.shutterAccent.opacity(0.22), .clear],
                            center: .center, startRadius: 10, endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 200)
                    .blur(radius: 22)

                Image(systemName: "macbook")
                    .font(.system(size: 96, weight: .thin))
                    .foregroundStyle(.primary.opacity(0.72))

                // Lock shield badge — sits on the upper-right of the Mac.
                ZStack {
                    Circle()
                        .fill(.background)
                        .frame(width: 62, height: 62)
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.shutterAccent)
                }
                .offset(x: 52, y: -28)
            }
            .frame(height: 180)
        }
    }

    /// Shield + key, suggesting a locked-but-recoverable system.
    struct Password: View {
        var body: some View {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.shutterAccent.opacity(0.28), .clear],
                            center: .center, startRadius: 10, endRadius: 110
                        )
                    )
                    .frame(width: 240, height: 200)
                    .blur(radius: 20)

                Image(systemName: "shield.fill")
                    .font(.system(size: 110, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.shutterAccent, Color.shutterAccent.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.shutterAccent.opacity(0.45), radius: 18, y: 8)

                Image(systemName: "key.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-20))
            }
            .frame(height: 180)
        }
    }

    /// Big seal with subtle confetti dots radiating around it.
    struct Ready: View {
        var body: some View {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.shutterAccent.opacity(0.35), .clear],
                            center: .center, startRadius: 10, endRadius: 120
                        )
                    )
                    .frame(width: 260, height: 200)
                    .blur(radius: 20)

                // Confetti ring — small dots arranged in a circle.
                ForEach(0..<10, id: \.self) { i in
                    let angle = Angle.degrees(Double(i) / 10.0 * 360.0)
                    Circle()
                        .fill(Color.shutterAccent.opacity(i.isMultiple(of: 2) ? 0.7 : 0.35))
                        .frame(width: i.isMultiple(of: 2) ? 8 : 5, height: i.isMultiple(of: 2) ? 8 : 5)
                        .offset(
                            x: cos(angle.radians) * 95,
                            y: sin(angle.radians) * 70
                        )
                }

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(Color.shutterAccent)
                    .shadow(color: Color.shutterAccent.opacity(0.45), radius: 20, y: 8)
            }
            .frame(height: 200)
        }
    }
}
