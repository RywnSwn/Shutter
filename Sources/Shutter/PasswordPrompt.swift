import AppKit
import SwiftUI

/// Modal password prompts. Returns the entered password via the completion handler (nil = cancelled).
@MainActor
enum PasswordPrompt {
    /// Single-field prompt for verifying a password (used when unlocking Secure Mode).
    /// Accepts either the user's password or their recovery code.
    static func verify(reason: String, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Enter password"
        alert.informativeText = reason + "\nForgot it? Enter your recovery code instead."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Password or recovery code"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { completion(false); return }
        completion(KeychainStore.verify(field.stringValue))
    }

    /// Two-field prompt for setting/changing a password. On success, generates a recovery code,
    /// stores it in Keychain, and shows it to the user so they can save it.
    static func setNew(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Set password"
        alert.informativeText = "Required to turn Secure Mode off. After saving, you'll see a one-time recovery code in case you forget it."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let container = NSStackView(frame: NSRect(x: 0, y: 0, width: 240, height: 60))
        container.orientation = .vertical
        container.spacing = 8
        container.alignment = .leading

        let pw = NSSecureTextField(); pw.placeholderString = "New password"
        let confirm = NSSecureTextField(); confirm.placeholderString = "Confirm password"
        pw.setFrameSize(NSSize(width: 240, height: 24))
        confirm.setFrameSize(NSSize(width: 240, height: 24))
        container.addArrangedSubview(pw)
        container.addArrangedSubview(confirm)
        alert.accessoryView = container
        alert.window.initialFirstResponder = pw

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { completion(false); return }

        let a = pw.stringValue, b = confirm.stringValue
        guard !a.isEmpty, a == b else {
            let err = NSAlert()
            err.messageText = "Passwords don't match"
            err.informativeText = a.isEmpty ? "Password cannot be empty." : "Re-enter the same password in both fields."
            err.runModal()
            completion(false); return
        }
        KeychainStore.setPassword(a)
        let code = RecoveryCode.generate()
        KeychainStore.setRecoveryCode(code)
        showRecoveryCode(code, isInitialReveal: true)
        completion(true)
    }

    /// Shows the stored recovery code in a copy-able dialog. Used right after password setup
    /// and from Settings ("View recovery code"). No-op if no code is stored.
    static func showRecoveryCode(_ code: String, isInitialReveal: Bool) {
        let alert = NSAlert()
        alert.messageText = isInitialReveal ? "Save your recovery code" : "Your recovery code"
        alert.informativeText = """
        \(code)

        Use this at the unlock prompt if you ever forget your password.
        Save it somewhere a kid won't find — a private password manager, a note on your phone, or paper kept off your desk.

        You can view this code again in Settings.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy Code")
        alert.addButton(withTitle: "Done")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(code, forType: .string)
        }
    }

    /// Generates and stores a recovery code for a user who already has a password but no code
    /// (legacy state from before this feature existed), then reveals it.
    static func generateAndShowRecoveryCode() {
        let code = RecoveryCode.generate()
        KeychainStore.setRecoveryCode(code)
        showRecoveryCode(code, isInitialReveal: true)
    }
}
