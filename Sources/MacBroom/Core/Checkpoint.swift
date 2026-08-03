import Foundation

/// What is known about a saved checkpoint without reading its (much larger) body.
struct CheckpointMeta: Codable, Identifiable, Hashable {
    var id = UUID()
    let root: String
    let takenAt: Date
    let total: Int64
    let fileCount: Int
    let entryCount: Int
}

/// Folder sizes as they were at one moment, kept so a later scan can be subtracted
/// from it: "since Monday, Library has grown 3 GB".
///
/// Only cumulative folder sizes are stored, never file names or contents — a
/// checkpoint has to be cheap enough to keep a dozen of them, and it must not turn
/// into a log of what the user has been doing.
struct DiskCheckpoint: Codable {
    let meta: CheckpointMeta
    /// Path relative to the root → cumulative bytes. The root itself is `""`.
    let sizes: [String: Int64]

    /// Entries below this are not stored. Every folder's size includes its
    /// children, so dropping the small ones loses no bytes from the total — the
    /// parent still accounts for them. It only limits how precisely a change can
    /// be blamed, and keeps a checkpoint at kilobytes instead of megabytes.
    /// Decimal, not 2 × 1024²: the figure is shown to the user, and "2 MB" reads
    /// better than the "2,1 MB" a binary megabyte prints as.
    static let minimumEntry: Int64 = 2_000_000

    static func make(from tree: DiskMapTree) -> DiskCheckpoint {
        let root = tree.root
        var sizes: [String: Int64] = [:]
        for (path, size) in tree.totals where size >= minimumEntry {
            guard let key = Self.relative(path, root: root) else { continue }
            sizes[key] = size
        }
        sizes[""] = tree.size(of: root)

        return DiskCheckpoint(
            meta: CheckpointMeta(
                root: root,
                takenAt: Date(),
                total: tree.size(of: root),
                fileCount: tree.fileCount,
                entryCount: sizes.count
            ),
            sizes: sizes
        )
    }

    func absolutePath(_ relative: String) -> String {
        relative.isEmpty ? meta.root : meta.root + "/" + relative
    }

    private static func relative(_ path: String, root: String) -> String? {
        if path == root { return "" }
        guard path.hasPrefix(root + "/") else { return nil }
        return String(path.dropFirst(root.count + 1))
    }
}

// MARK: - Comparison

/// Two checkpoints subtracted from each other.
struct DiskComparison {
    enum Kind: String {
        case appeared
        case vanished
        case changed
    }

    struct Row: Identifiable {
        let relative: String
        let name: String
        let path: String
        let before: Int64
        let after: Int64
        /// Change including everything inside this folder.
        let delta: Int64
        /// Change this folder is responsible for on its own — its `delta` minus
        /// whatever its tracked children already explain. This is what gets shown,
        /// so a 3 GB build folder is reported once instead of also being counted
        /// again in every parent above it.
        let exclusive: Int64
        let kind: Kind

        var id: String { relative }
        var url: URL { URL(fileURLWithPath: path) }
    }

    let before: CheckpointMeta
    let after: CheckpointMeta
    let rows: [Row]
    /// How the whole tree changed.
    let netChange: Int64
    let grown: Int64
    let freed: Int64
    /// Bytes not attributable to any single folder above the display floor —
    /// the sum of many changes too small to list.
    let scattered: Int64

    var span: TimeInterval { after.takenAt.timeIntervalSince(before.takenAt) }

    /// Changes smaller than this are added up into `scattered` rather than listed.
    static let minimumChange: Int64 = 10_000_000

    /// Returns nil if the two checkpoints measured different folders — their
    /// numbers are not comparable and pretending otherwise would invent changes.
    static func between(
        _ before: DiskCheckpoint,
        _ after: DiskCheckpoint,
        minimum: Int64 = minimumChange
    ) -> DiskComparison? {
        guard before.meta.root == after.meta.root else { return nil }

        var deltas: [String: Int64] = after.sizes
        for (key, size) in before.sizes {
            deltas[key, default: 0] -= size
        }

        // Bytes each folder's children account for. Because folder sizes are
        // cumulative, subtracting this leaves exactly the part that is this
        // folder's own doing, and the exclusive figures then sum to the root's
        // change with nothing double counted.
        var childDeltas: [String: Int64] = [:]
        for (key, delta) in deltas where !key.isEmpty {
            childDeltas[(key as NSString).deletingLastPathComponent, default: 0] += delta
        }

        var rows: [Row] = []
        var grown: Int64 = 0
        var freed: Int64 = 0
        var listed: Int64 = 0

        for (key, delta) in deltas where !key.isEmpty {
            let exclusive = delta - (childDeltas[key] ?? 0)
            if exclusive > 0 { grown += exclusive } else { freed += exclusive }
            guard abs(exclusive) >= minimum else { continue }
            listed += exclusive

            let existedBefore = before.sizes[key] != nil
            let existsNow = after.sizes[key] != nil
            rows.append(
                Row(
                    relative: key,
                    name: (key as NSString).lastPathComponent,
                    path: after.absolutePath(key),
                    before: before.sizes[key] ?? 0,
                    after: after.sizes[key] ?? 0,
                    delta: delta,
                    exclusive: exclusive,
                    kind: !existedBefore ? .appeared : (!existsNow ? .vanished : .changed)
                )
            )
        }

        rows.sort { abs($0.exclusive) > abs($1.exclusive) }
        let net = deltas[""] ?? (after.meta.total - before.meta.total)

        return DiskComparison(
            before: before.meta,
            after: after.meta,
            rows: rows,
            netChange: net,
            grown: grown,
            freed: freed,
            scattered: net - listed
        )
    }
}

// MARK: - Storage

/// Keeps checkpoints on disk next to the app's other state.
actor CheckpointStore {
    static let shared = CheckpointStore()

    /// Enough to look back a couple of months at a weekly rhythm; the oldest is
    /// dropped past this so the folder cannot grow without limit.
    private static let maximum = 12

    private let folder: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacBroom/checkpoints", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    /// Newest first. Reads only the small index, not the checkpoints themselves.
    func index() -> [CheckpointMeta] {
        guard let data = try? Data(contentsOf: indexURL),
            let list = try? JSONDecoder().decode([CheckpointMeta].self, from: data)
        else { return rebuildIndex() }
        return list.sorted { $0.takenAt > $1.takenAt }
    }

    func load(_ id: UUID) -> DiskCheckpoint? {
        guard let data = try? Data(contentsOf: bodyURL(id)) else { return nil }
        return try? JSONDecoder().decode(DiskCheckpoint.self, from: data)
    }

    @discardableResult
    func save(_ checkpoint: DiskCheckpoint) -> Bool {
        guard let data = try? JSONEncoder().encode(checkpoint) else { return false }
        do {
            try data.write(to: bodyURL(checkpoint.meta.id), options: .atomic)
        } catch {
            return false
        }
        var list = index()
        list.append(checkpoint.meta)
        list.sort { $0.takenAt > $1.takenAt }
        for stale in list.dropFirst(Self.maximum) {
            try? FileManager.default.removeItem(at: bodyURL(stale.id))
        }
        writeIndex(Array(list.prefix(Self.maximum)))
        return true
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: bodyURL(id))
        writeIndex(index().filter { $0.id != id })
    }

    func clear() {
        for meta in index() {
            try? FileManager.default.removeItem(at: bodyURL(meta.id))
        }
        writeIndex([])
    }

    // MARK: - Files

    private var indexURL: URL { folder.appendingPathComponent("index.json") }

    private func bodyURL(_ id: UUID) -> URL {
        folder.appendingPathComponent("\(id.uuidString).json")
    }

    private func writeIndex(_ list: [CheckpointMeta]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(list) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// The checkpoints are self-describing, so a lost or corrupt index is not a
    /// lost history — it is rebuilt by reading them.
    private func rebuildIndex() -> [CheckpointMeta] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let metas = files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "index.json" }
            .compactMap { url -> CheckpointMeta? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return (try? JSONDecoder().decode(DiskCheckpoint.self, from: data))?.meta
            }
            .sorted { $0.takenAt > $1.takenAt }
        if !metas.isEmpty { writeIndex(metas) }
        return metas
    }
}
