import Foundation

enum Format {
    /// Signed byte size, e.g. "+1.2 GB" / "−340 MB".
    ///
    /// `bytes(_:)` clamps negatives to zero, which is right for a size and wrong
    /// for a delta: it turned every shrink in the growth watcher into "Zero KB".
    static func signedBytes(_ value: Int64) -> String {
        if value == 0 { return "0" }
        let sign = value > 0 ? "+" : "−"
        return sign + bytes(abs(value))
    }

    /// Human readable byte size, e.g. "1.2 GB".
    static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        f.zeroPadsFractionDigits = false
        return f.string(fromByteCount: max(0, value))
    }

    static func date(_ value: Date?) -> String {
        guard let value else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: value)
    }

    static func age(_ value: Date?) -> String {
        guard let value else { return "" }
        let language = Localized.current
        let days = Int(Date().timeIntervalSince(value) / 86_400)
        if days < 1 { return S.ageToday(language) }
        if days < 30 { return S.ageDays(days)(language) }
        if days < 365 { return S.ageMonths(days / 30)(language) }
        return S.ageYears(days / 365)(language)
    }
}
