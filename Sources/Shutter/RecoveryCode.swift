import Foundation

/// Generates human-readable recovery codes used as an alternative to the user's password.
/// Format: XXXX-XXXX-XXXX (12 characters from an ambiguity-free alphabet, grouped for readability).
enum RecoveryCode {
    /// Excludes 0/O and 1/I/L to avoid hand-copying mistakes.
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        let groups = (0..<3).map { _ -> String in
            String((0..<4).map { _ in alphabet.randomElement()! })
        }
        return groups.joined(separator: "-")
    }

    /// Normalizes user input before comparing: trims whitespace, uppercases, removes spaces
    /// and dashes. Means "abcd efgh jkmn" and "ABCD-EFGH-JKMN" both match the same stored code.
    static func normalize(_ input: String) -> String {
        input.uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
