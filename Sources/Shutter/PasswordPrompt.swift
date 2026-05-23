import AppKit
import SwiftUI

/// Modal password prompts. Returns the entered password via the completion handler (nil = cancelled).
@MainActor
enum PasswordPrompt {
    /// Single-field prompt for verifying a password (used when unlocking Secure Mode).
    static func verify(reason: String, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Enter password"
        alert.informativeText = reason
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Password"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { completion(false); return }
        completion(KeychainStore.verify(field.stringValue))
    }

    /// Two-field prompt for setting/changing a password.
    static func setNew(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Set password"
        alert.informativeText = "You'll need this to turn Secure Mode off. If you forget it, you can remove it via Keychain Access."
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
        completion(true)
    }
}
