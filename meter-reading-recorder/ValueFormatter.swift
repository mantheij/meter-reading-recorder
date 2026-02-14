import Foundation

struct ValueFormatter {
    /// Sanitizes a meter reading value: trims whitespace, normalizes comma to dot,
    /// keeps only digits and at most one dot. Returns nil if no digits are present.
    static func sanitizeMeterValue(_ input: String) -> String? {
        var filtered = input.trimmingCharacters(in: .whitespacesAndNewlines)
        filtered = filtered.replacingOccurrences(of: ",", with: ".")
        filtered = filtered.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        if let firstDot = filtered.firstIndex(of: ".") {
            let after = filtered[filtered.index(after: firstDot)...].replacingOccurrences(of: ".", with: "")
            filtered = String(filtered[..<filtered.index(after: firstDot)]) + after
        }
        let digitsOnly = filtered.replacingOccurrences(of: ".", with: "")
        guard !digitsOnly.isEmpty else { return nil }
        return filtered
    }
}
