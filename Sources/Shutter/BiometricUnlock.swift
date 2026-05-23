import Foundation
import LocalAuthentication

/// Unlocks Secure Mode by trying Touch ID first, then our app password as a fallback.
/// Touch ID alone isn't enough — if the Mac has no biometric or the user cancels, we fall back.
@MainActor
enum BiometricUnlock {
    /// Asks the user to authenticate. Calls `completion(true)` if authenticated by EITHER:
    ///   - Touch ID, OR
    ///   - the correct app password (if one is set)
    /// Calls `completion(false)` if they cancel or fail both.
    static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = KeychainStore.hasPassword ? "Use App Password" : ""

        var error: NSError?
        let canUseBiometrics = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        guard canUseBiometrics else {
            // No Touch ID available — go straight to password (if set) or just allow.
            fallbackToPassword(reason: reason, completion: completion)
            return
        }

        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                if success {
                    completion(true)
                } else {
                    // User cancelled or biometric failed — offer password fallback if available.
                    fallbackToPassword(reason: reason, completion: completion)
                }
            }
        }
    }

    private static func fallbackToPassword(reason: String, completion: @escaping (Bool) -> Void) {
        if KeychainStore.hasPassword {
            PasswordPrompt.verify(reason: reason, completion: completion)
        } else {
            // Nothing protecting it — let it through.
            completion(true)
        }
    }
}
