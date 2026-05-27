import Foundation
import Security

/// Stores the Secure Mode password — and an optional recovery code — in the macOS Keychain.
/// Neither is ever written to disk in plaintext.
enum KeychainStore {
    private static let service = "Shutter"
    private static let passwordAccount = "secureModePassword"
    private static let recoveryAccount = "secureModeRecoveryCode"

    // MARK: - Password

    static var hasPassword: Bool {
        load(account: passwordAccount) != nil
    }

    static func setPassword(_ password: String) {
        write(account: passwordAccount, value: password)
    }

    static func clearPassword() {
        delete(account: passwordAccount)
        // A password without recovery code is the legacy state; a recovery code without a
        // password is meaningless. Always clear both together.
        delete(account: recoveryAccount)
    }

    // MARK: - Recovery code

    static var hasRecoveryCode: Bool {
        load(account: recoveryAccount) != nil
    }

    static func setRecoveryCode(_ code: String) {
        write(account: recoveryAccount, value: code)
    }

    static func recoveryCode() -> String? {
        load(account: recoveryAccount)
    }

    // MARK: - Verify

    /// Returns true if `input` matches the stored password OR the stored recovery code.
    /// Returns false if nothing is stored.
    static func verify(_ input: String) -> Bool {
        if let stored = load(account: passwordAccount), stored == input { return true }
        if let stored = load(account: recoveryAccount),
           RecoveryCode.normalize(stored) == RecoveryCode.normalize(input) { return true }
        return false
    }

    // MARK: - Internals

    private static func write(account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        _ = SecItemDelete(baseQuery(account: account) as CFDictionary)
        var addQuery = baseQuery(account: account)
        addQuery[kSecValueData as String] = data
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func delete(account: String) {
        _ = SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func load(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
