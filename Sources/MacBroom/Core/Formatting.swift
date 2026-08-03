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
        // Otherwise zero prints as "Zero KB", which reads like an error next to a
        // real figure ("524,3 MB → Zero KB").
        f.allowsNonnumericFormatting = false
        return f.string(fromByteCount: max(0, value))
    }

    /// Day and time, written the way the chosen language writes it.
    static func dateTime(_ value: Date) -> String {
        let f = DateFormatter()
        f.locale = Localized.current.locale
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: value)
    }

    /// "2 days, 4 hours" — a length of time, in the chosen language.
    ///
    /// Foundation already knows how every language writes this, so the units are
    /// not hand-translated: only the locale is swapped for the one the user picked,
    /// which may differ from the system's.
    static func span(_ seconds: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.calendar?.locale = Localized.current.locale
        f.unitsStyle = .full
        f.maximumUnitCount = 2
        f.allowedUnits = seconds < 3_600 ? [.minute] : [.day, .hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        return f.string(from: max(60, seconds)) ?? ""
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
