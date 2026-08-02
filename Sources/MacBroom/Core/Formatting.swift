import Foundation

enum Format {
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
        let uz = Localized.current == .uz
        let days = Int(Date().timeIntervalSince(value) / 86_400)
        if days < 1 { return uz ? "bugun" : "today" }
        if days < 30 { return uz ? "\(days) kun oldin" : "\(days)d ago" }
        if days < 365 { return uz ? "\(days / 30) oy oldin" : "\(days / 30)mo ago" }
        return uz ? "\(days / 365) yil oldin" : "\(days / 365)y ago"
    }
}
