import Foundation

@MainActor
final class DiskMapModel: ObservableObject {
    @Published var root: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published private(set) var tree: DiskMapTree?
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var scannedFiles = 0
    @Published private(set) var scannedBytes: Int64 = 0
    /// Breadcrumb: root first, current folder last.
    @Published private(set) var trail: [String] = []

    private var task: Task<Void, Never>?

    var currentPath: String { trail.last ?? root.path }
    var currentSize: Int64 { tree?.size(of: currentPath) ?? 0 }
    var canGoUp: Bool { trail.count > 1 }

    var nodes: [MapNode] {
        guard let tree else { return [] }
        let all = tree.nodes(under: currentPath)
        // Below a thousandth of the parent a tile is a hairline — not worth drawing.
        let floor = max(Int64(1), currentSize / 1000)
        return all.filter { $0.size >= floor }
    }

    func scan() {
        task?.cancel()
        isScanning = true
        hasScanned = false
        tree = nil
        trail = []
        scannedFiles = 0
        scannedBytes = 0

        let root = self.root
        task = Task { [weak self] in
            guard let self else { return }

            let built = await Task.detached(priority: .userInitiated) { () -> DiskMapTree in
                DiskMapTree.build(root: root) { progress in
                    Task { @MainActor [weak self] in
                        self?.scannedFiles = progress.files
                        self?.scannedBytes = progress.bytes
                    }
                }
            }.value

            if Task.isCancelled { return }
            self.tree = built
            self.trail = [built.root]
            self.isScanning = false
            self.hasScanned = true
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isScanning = false
        hasScanned = true
    }

    func open(_ node: MapNode) {
        guard node.isDirectory, tree?.children[node.path]?.isEmpty == false else { return }
        trail.append(node.path)
    }

    func goUp() {
        guard canGoUp else { return }
        trail.removeLast()
    }

    func go(to index: Int) {
        guard index >= 0, index < trail.count else { return }
        trail = Array(trail.prefix(index + 1))
    }

    var breadcrumb: [(index: Int, name: String)] {
        trail.enumerated().map { index, path in
            (index, index == 0 ? (path as NSString).lastPathComponent : (path as NSString).lastPathComponent)
        }
    }
}
