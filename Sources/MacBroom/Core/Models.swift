import Foundation

enum RiskLevel: String {
    case safe
    case caution

    var label: T { self == .safe ? S.riskSafe : S.riskReview }
}

/// A plain-language recommendation shown next to anything the user can remove or quit.
/// The point is that "you may" and "you should not" are different answers, and the app
/// should say which one it means instead of leaving the user to guess.
enum Advice: String {
    /// Nothing depends on it — go ahead.
    case removable
    /// Left over from something that already closed. The best thing to clean up.
    case leftover
    /// Something is actively using it right now (open app, a listening port).
    case inUse
    /// macOS needs it. Touching it gains nothing.
    case keep

    var label: T {
        switch self {
        case .removable: return S.adviceRemovable
        case .leftover: return S.adviceLeftover
        case .inUse: return S.adviceInUse
        case .keep: return S.adviceKeep
        }
    }

    var explanation: T {
        switch self {
        case .removable: return S.adviceRemovableWhy
        case .leftover: return S.adviceLeftoverWhy
        case .inUse: return S.adviceInUseWhy
        case .keep: return S.adviceKeepWhy
        }
    }
}

/// One removable thing found on disk.
struct ScanItem: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let size: Int64
    let modified: Date?
    var isSelected: Bool
    var advice: Advice = .removable

    var id: String { url.path }
}

enum CategoryID: String, CaseIterable, Identifiable {
    case userCaches
    case appLogs
    case xcode
    case devCaches
    case browsers
    case trash
    case mail
    case iosBackups
    case oldDownloads

    var id: String { rawValue }

    var title: T {
        switch self {
        case .userCaches: return S.catUserCaches
        case .appLogs: return S.catLogs
        case .xcode: return S.catXcode
        case .devCaches: return S.catDev
        case .browsers: return S.catBrowsers
        case .trash: return S.catTrash
        case .mail: return S.catMail
        case .iosBackups: return S.catBackups
        case .oldDownloads: return S.catInstallers
        }
    }

    var subtitle: T {
        switch self {
        case .userCaches: return S.catUserCachesSub
        case .appLogs: return S.catLogsSub
        case .xcode: return S.catXcodeSub
        case .devCaches: return S.catDevSub
        case .browsers: return S.catBrowsersSub
        case .trash: return S.catTrashSub
        case .mail: return S.catMailSub
        case .iosBackups: return S.catBackupsSub
        case .oldDownloads: return S.catInstallersSub
        }
    }

    var symbol: String {
        switch self {
        case .userCaches: return "shippingbox"
        case .appLogs: return "doc.text"
        case .xcode: return "hammer"
        case .devCaches: return "chevron.left.forwardslash.chevron.right"
        case .browsers: return "globe"
        case .trash: return "trash"
        case .mail: return "envelope"
        case .iosBackups: return "iphone"
        case .oldDownloads: return "arrow.down.circle"
        }
    }

    var risk: RiskLevel {
        switch self {
        case .userCaches, .appLogs, .xcode, .devCaches, .browsers, .trash, .mail:
            return .safe
        case .iosBackups, .oldDownloads:
            return .caution
        }
    }

    /// Order shown in the UI.
    static let displayOrder: [CategoryID] = [
        .userCaches, .devCaches, .xcode, .browsers, .appLogs, .mail, .trash, .oldDownloads, .iosBackups,
    ]
}

struct ScanCategory: Identifiable {
    let id: CategoryID
    var items: [ScanItem]
    var isExpanded: Bool = false

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.count(where: \.isSelected) }

    var selectionState: SelectionState {
        if items.isEmpty { return .none }
        if selectedCount == items.count { return .all }
        return selectedCount == 0 ? .none : .partial
    }

    enum SelectionState { case none, partial, all }
}

extension Array where Element == ScanCategory {
    var totalSize: Int64 { reduce(0) { $0 + $1.totalSize } }
    var selectedSize: Int64 { reduce(0) { $0 + $1.selectedSize } }
    var selectedCount: Int { reduce(0) { $0 + $1.selectedCount } }
}

private extension Array {
    func count(where predicate: (Element) -> Bool) -> Int {
        reduce(0) { predicate($1) ? $0 + 1 : $0 }
    }
}
