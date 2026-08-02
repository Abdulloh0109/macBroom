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
            .isDirectoryKey, .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
        ]
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

// MARK: - Squarified treemap

/// Lays out sizes as rectangles that stay close to square, so small items are
/// still clickable instead of degenerating into slivers.
/// Bruls, Huizing & van Wijk, "Squarified Treemaps" (2000).
enum Treemap {
    struct Tile {
        let index: Int
        let rect: CGRect
    }

    static func layout(sizes: [Int64], in bounds: CGRect) -> [Tile] {
        let total = sizes.reduce(0, +)
        guard total > 0, !sizes.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }

        let scale = Double(bounds.width * bounds.height) / Double(total)
        var remaining = sizes.enumerated().map { (index: $0.offset, area: Double($0.element) * scale) }
        remaining.sort { $0.area > $1.area }

        var tiles: [Tile] = []
        var rect = bounds
        var row: [(index: Int, area: Double)] = []

        func shortestSide(_ r: CGRect) -> Double { Double(min(r.width, r.height)) }

        /// Worst aspect ratio in `row` if laid along the shorter side of `r`.
        func worst(_ row: [(index: Int, area: Double)], _ side: Double) -> Double {
            guard !row.isEmpty, side > 0 else { return .infinity }
            let sum = row.reduce(0) { $0 + $1.area }
            guard sum > 0 else { return .infinity }
            let maxArea = row.map(\.area).max() ?? 0
            let minArea = row.map(\.area).min() ?? 0
            let side2 = side * side
            let sum2 = sum * sum
            return max(side2 * maxArea / sum2, sum2 / (side2 * minArea))
        }

        func flush(_ row: [(index: Int, area: Double)], into r: CGRect) -> CGRect {
            let sum = row.reduce(0) { $0 + $1.area }
            guard sum > 0 else { return r }
            let horizontal = r.width >= r.height
            var offset: Double = 0
            let thickness = sum / Double(horizontal ? r.height : r.width)

            for item in row {
                let length = item.area / thickness
                let tile: CGRect
                if horizontal {
                    tile = CGRect(x: r.minX, y: r.minY + offset, width: thickness, height: length)
                } else {
                    tile = CGRect(x: r.minX + offset, y: r.minY, width: length, height: thickness)
                }
                tiles.append(Tile(index: item.index, rect: tile))
                offset += length
            }

            return horizontal
                ? CGRect(x: r.minX + thickness, y: r.minY, width: r.width - thickness, height: r.height)
                : CGRect(x: r.minX, y: r.minY + thickness, width: r.width, height: r.height - thickness)
        }

        var queue = remaining
        while !queue.isEmpty {
            let side = shortestSide(rect)
            let item = queue[0]

            if row.isEmpty || worst(row + [item], side) <= worst(row, side) {
                row.append(item)
                queue.removeFirst()
            } else {
                rect = flush(row, into: rect)
                row = []
            }
        }
        if !row.isEmpty { _ = flush(row, into: rect) }

        return tiles
    }
}
