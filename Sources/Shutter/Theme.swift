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
