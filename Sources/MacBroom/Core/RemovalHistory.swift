import AppKit
import Foundation

/// One thing that was removed, and where it went.
///
/// `trashedPath` is the whole point: `trashItem` reports where in the Trash the
/// item landed, and keeping that turns "it's in the Trash somewhere" into a
/// button that puts it back exactly where it came from.
struct RemovalRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    let displayName: String
    let originalPath: String
    let trashedPath: String?
    let size: Int64

    /// Still sitting in the Trash, and nothing has taken its old place.
    var canRestore: Bool {
        guard let trashedPath else { return false }
        let fm = FileManager.default
        return fm.fileExists(atPath: trashedPath) && !fm.fileExists(atPath: originalPath)
    }

    var isGoneForever: Bool {
        guard let trashedPath else { return true }
        return !FileManager.default.fileExists(atPath: trashedPath)
    }
}

enum RemovalSource: String, Codable {
    case smartScan
    case largeFiles
    case projects
    case apps
    case services

    var label: T {
        switch self {
        case .smartScan: return S.smartScan
        case .largeFiles: return S.largeFiles
        case .projects: return S.projects
        case .apps: return S.apps
        case .services: return S.services
        }
    }
}

struct RemovalSession: Codable, Identifiable, Hashable {
    var id = UUID()
    let date: Date
    let source: RemovalSource
    var records: [RemovalRecord]

    var freed: Int64 { records.reduce(0) { $0 + $1.size } }
    var restorableCount: Int { records.count(where: \.canRestore) }
}

/// Append-only log of everything MacBroom has removed, kept next to the app's
/// own preferences so it survives restarts.
///
/// This exists because "we moved it to the Trash" is not the same as being able
/// to answer "what did you remove last Tuesday, and can I have it back?" — the
/// single most common complaint about cleaners of this kind.
actor RemovalHistory {
    static let shared = RemovalHistory()

    private static let maximumSessions = 300

    private let fileURL: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacBroom", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }()

    private var sessions: [RemovalSession] = []
    private var loaded = false

    func all() -> [RemovalSession] {
        load()
        return sessions.sorted { $0.date > $1.date }
    }

    func add(source: RemovalSource, records: [RemovalRecord]) {
        guard !records.isEmpty else { return }
        load()
        sessions.append(RemovalSession(date: Date(), source: source, records: records))
        if sessions.count > Self.maximumSessions {
            sessions.removeFirst(sessions.count - Self.maximumSessions)
        }
        save()
    }

    func forget(_ sessionID: UUID) {
        load()
        sessions.removeAll { $0.id == sessionID }
        save()
    }

    func clear() {
        sessions = []
        loaded = true
        save()
    }

    /// Moves an item back out of the Trash to where it came from.
    func restore(_ record: RemovalRecord) -> Result<Void, RestoreError> {
        guard let trashedPath = record.trashedPath else { return .failure(.notInTrash) }
        let fm = FileManager.default
        guard fm.fileExists(atPath: trashedPath) else { return .failure(.trashEmptied) }

        let destination = URL(fileURLWithPath: record.originalPath)
        guard !fm.fileExists(atPath: destination.path) else { return .failure(.occupied) }

        // Restoring writes into the same places removal was allowed from, so the
        // same guard applies — a history file edited by hand cannot be used to
        // drop files into arbitrary locations.
        guard SafetyGuard.isRemovable(destination) else { return .failure(.refused) }

        try? fm.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        do {
            try fm.moveItem(at: URL(fileURLWithPath: trashedPath), to: destination)
        } catch {
            // Moving *out* of ~/.Trash is a protected operation. The same binary run
            // from Terminal inherits Terminal's Full Disk Access and succeeds, while
            // the signed .app has its own TCC identity and does not — so a direct
            // move works in tests and fails in the shipped app. Finder is allowed to
            // do it, so ask Finder; that surfaces a one-time Automation prompt, which
            // is consent the user can see rather than a privilege grab.
            if let finderError = Self.askFinderToMove(trashedPath, to: destination) {
                return .failure(.needsPermission(finderError))
            }
            guard fm.fileExists(atPath: destination.path) else {
                return .failure(.needsPermission(error.localizedDescription))
            }
        }

        // Drop the record: it is no longer something that was removed.
        load()
        for index in sessions.indices {
            sessions[index].records.removeAll { $0.id == record.id }
        }
        sessions.removeAll { $0.records.isEmpty }
        save()
        return .success(())
    }

    /// Hands the move to Finder, which is permitted inside the Trash.
    /// Returns nil on success, or a message describing what went wrong.
    private static func askFinderToMove(_ trashedPath: String, to destination: URL) -> String? {
        let parent = destination.deletingLastPathComponent().path
        let script = """
            tell application "Finder"
                move (POSIX file "\(trashedPath)" as alias) to (POSIX file "\(parent)" as alias)
            end tell
            """

        var errorInfo: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
        if let errorInfo, let message = errorInfo[NSAppleScript.errorMessage] as? String {
            return message
        }

        // Finder keeps the name it had in the Trash, which may have been made unique
        // ("foo 2"), so put the original name back.
        let fm = FileManager.default
        let landed = URL(fileURLWithPath: parent)
            .appendingPathComponent((trashedPath as NSString).lastPathComponent)
        if landed.path != destination.path, fm.fileExists(atPath: landed.path) {
            try? fm.moveItem(at: landed, to: destination)
        }
        return fm.fileExists(atPath: destination.path) ? nil : "Finder did not move it"
    }

    enum RestoreError: LocalizedError {
        case notInTrash
        case trashEmptied
        case occupied
        case refused
        case needsPermission(String)

        var message: T {
            switch self {
            case .notInTrash, .trashEmptied: return S.restoreGone
            case .occupied: return S.restoreOccupied
            case .refused: return S.restoreRefused
            case .needsPermission: return S.restoreNeedsPermission
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([RemovalSession].self, from: data)
        else { return }
        sessions = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

private extension Array {
    func count(where predicate: (Element) -> Bool) -> Int {
        reduce(0) { predicate($1) ? $0 + 1 : $0 }
    }
}
