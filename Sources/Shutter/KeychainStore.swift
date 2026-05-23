import Foundation
import Security

/// Stores the Secure Mode password in the macOS Keychain. Never written to disk in plaintext.
enum KeychainStore {
    private static let service = "Shutter"
    private static let account = "secureModePassword"

    static var hasPassword: Bool {
        load() != nil
    }

    static func setPassword(_ password: String) {
        guard let data = password.data(using: .utf8) else { return }
        // Delete any existing item first — SecItemUpdate is finicky across edge cases.
        _ = SecItemDelete(baseQuery as CFDictionary)
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func clearPassword() {
        _ = SecItemDelete(baseQuery as CFDictionary)
    }

    /// Returns true if `password` matches what's stored. Returns false if nothing is stored.
    static func verify(_ password: String) -> Bool {
        guard let stored = load() else { return false }
        return stored == password
    }

    private static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
