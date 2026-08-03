import Foundation

/// One box in the map: a directory or a file, with its cumulative size.
struct MapNode: Identifiable, Hashable {
    let path: String
    let name: String
    let size: Int64
    let isDirectory: Bool

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
}

/// The whole tree, built in a single filesystem walk.
///
/// Computing each folder's size on demand would mean re-walking the same files
/// every time the user drills in. Instead one pass adds every file's size to all
/// of its ancestors, and navigation afterwards is instant dictionary lookups.
struct DiskMapTree {
    let root: String
    /// Cumulative size for every path within the depth limit.
    private(set) var totals: [String: Int64] = [:]
    private(set) var children: [String: Set<String>] = [:]
    private(set) var directories: Set<String> = []
    private(set) var fileCount = 0

    init(root: String) {
        self.root = root
    }

    func size(of path: String) -> Int64 { totals[path] ?? 0 }

    /// Direct children of `path`, largest first, with anything tiny folded away
    /// by the caller if it wants to.
    func nodes(under path: String) -> [MapNode] {
        (children[path] ?? []).map { child in
            MapNode(
                path: child,
                name: (child as NSString).lastPathComponent,
                size: totals[child] ?? 0,
                isDirectory: directories.contains(child)
            )
        }
        .sorted { $0.size > $1.size }
    }

    // MARK: - Building

    struct Progress {
        var files: Int
        var bytes: Int64
    }

    /// Files smaller than this never become their own tile — they only add to their
    /// folder's total. Keeps the node table small on a disk with a million files.
    private static let fileNodeThreshold: Int64 = 8 * 1_024 * 1_024

    /// Walks `root` once.
    ///
    /// The obvious implementation — add every file's size to each of its ancestors —
    /// is quadratic-ish in practice: a million files times eight levels of path-string
    /// work. Instead each file adds only to its immediate parent, and directory totals
    /// roll up afterwards in one pass over the (far smaller) set of directories.
    /// Depth comes from the enumerator rather than from splitting path strings.
    static func build(
        root: URL,
        maxDepth: Int = 6,
        onProgress: (@Sendable (Progress) -> Void)? = nil
    ) -> DiskMapTree {
        let rootPath = root.standardizedFileURL.path
        var tree = DiskMapTree(root: rootPath)

        let keys: [URLResourceKey] = [
            // volumeIdentifier is fetched per directory below, not prefetched for
            // every file — that costs a statfs each and halves the walk speed.
            .isDirectoryKey, .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
        ]
        let rootVolume = (try? root.resourceValues(forKeys: [.volumeIdentifierKey]))?
            .volumeIdentifier
        let keySet = Set(keys)
        guard
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [],
                errorHandler: { _, _ in true }
            )
        else { return tree }

        /// Bytes sitting directly in each directory, before children roll up.
        var own: [String: Int64] = [:]
        /// Depth per directory, so the roll-up can go deepest-first.
        var depths: [String: Int] = [rootPath: 0]
        tree.directories.insert(rootPath)
        own[rootPath] = 0

        var totalBytes: Int64 = 0

        while let next = enumerator.nextObject() {
            guard let url = next as? URL else { continue }
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: keySet) else { continue }

            let level = enumerator.level  // 1 for direct children of root
            let path = url.path

            if values.isSymbolicLink == true {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }

            if values.isDirectory == true {
                // Never walk into a mounted volume: its contents are counted
                // against that volume, not this one.
                let childVolume = (try? url.resourceValues(forKeys: [.volumeIdentifierKey]))?
                    .volumeIdentifier
                if let rootVolume, let childVolume, !childVolume.isEqual(rootVolume) {
                    enumerator.skipDescendants()
                    continue
                }
                guard level <= maxDepth else {
                    enumerator.skipDescendants()
                    continue
                }
                tree.directories.insert(path)
                depths[path] = level
                if own[path] == nil { own[path] = 0 }
                tree.children[(path as NSString).deletingLastPathComponent, default: []].insert(path)

                // At the depth limit the subtree is measured in one go instead of
                // being walked here, so nothing below is lost from the totals.
                if level == maxDepth {
                    let size = SizeCalculator.size(of: url)
                    own[path, default: 0] += size
                    totalBytes += size
                    enumerator.skipDescendants()
                    onProgress?(Progress(files: tree.fileCount, bytes: totalBytes))
                }
                continue
            }

            let size = Int64(
                values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0
            )
            guard size > 0 else { continue }

            tree.fileCount += 1
            totalBytes += size

            let parent = (path as NSString).deletingLastPathComponent
            if size >= fileNodeThreshold {
                // Big enough to deserve its own box in the map.
                tree.totals[path] = size
                tree.children[parent, default: []].insert(path)
            } else {
                own[parent, default: 0] += size
            }

            if tree.fileCount & 0x3FFF == 0 {
                onProgress?(Progress(files: tree.fileCount, bytes: totalBytes))
            }
        }

        // Roll directory totals up, deepest first, so each parent sees finished children.
        for directory in depths.keys.sorted(by: { (depths[$0] ?? 0) > (depths[$1] ?? 0) }) {
            let childTotal = (tree.children[directory] ?? []).reduce(Int64(0)) {
                $0 + (tree.totals[$1] ?? 0)
            }
            tree.totals[directory] = (own[directory] ?? 0) + childTotal
        }

        onProgress?(Progress(files: tree.fileCount, bytes: totalBytes))
        return tree
    }
}

// MARK: - Circle packing

/// Packs circles around a centre, biggest first, each as close in as it will fit.
/// Area is proportional to size, so radius goes with the square root — a folder
/// twice as big draws twice the area, not twice the width.
enum CirclePack {
    struct Bubble: Identifiable {
        let id: Int
        let center: CGPoint
        let radius: Double
    }

    static func layout(sizes: [Int64], in bounds: CGRect, padding: Double = 5) -> [Bubble] {
        guard !sizes.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }

        let radii = sizes.map { Double($0).squareRoot() }
        guard let largest = radii.max(), largest > 0 else { return [] }
        let normalized = radii.map { $0 / largest * 100 }

        // Biggest first: the centre of the cluster is the thing worth looking at.
        let order = normalized.indices.sorted { normalized[$0] > normalized[$1] }
        var placed: [(index: Int, center: CGPoint, radius: Double)] = []

        for position in order {
            let r = normalized[position]
            guard r > 0.4 else { continue }  // sub-pixel once scaled — not worth a bubble

            if placed.isEmpty {
                placed.append((position, .zero, r))
                continue
            }

            // Walk outwards along a spiral and take the first spot that clears
            // everything already placed.
            var found: CGPoint? = nil
            let step = max(1.0, r * 0.28)
            var angle = 0.0
            while angle < 260 * .pi, found == nil {
                let distance = step * angle / (2 * .pi)
                let candidate = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
                let clears = placed.allSatisfy { other in
                    let dx = candidate.x - other.center.x
                    let dy = candidate.y - other.center.y
                    return (dx * dx + dy * dy).squareRoot() >= r + other.radius + padding
                }
                if clears { found = candidate }
                angle += 0.22
            }
            placed.append((position, found ?? .zero, r))
        }

        guard !placed.isEmpty else { return [] }

        // Fit the cluster's real bounding box, not a circle around the origin — the
        // spiral grows lopsidedly, and centring on the origin leaves dead space.
        let minX = placed.map { $0.center.x - $0.radius }.min() ?? 0
        let maxX = placed.map { $0.center.x + $0.radius }.max() ?? 0
        let minY = placed.map { $0.center.y - $0.radius }.min() ?? 0
        let maxY = placed.map { $0.center.y + $0.radius }.max() ?? 0

        let width = max(maxX - minX, 0.001)
        let height = max(maxY - minY, 0.001)
        let scale = min(bounds.width / width, bounds.height / height) * 0.96

        let clusterMid = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let viewMid = CGPoint(x: bounds.midX, y: bounds.midY)

        return placed.map {
            Bubble(
                id: $0.index,
                center: CGPoint(
                    x: viewMid.x + ($0.center.x - clusterMid.x) * scale,
                    y: viewMid.y + ($0.center.y - clusterMid.y) * scale
                ),
                radius: $0.radius * scale
            )
        }
    }
}
