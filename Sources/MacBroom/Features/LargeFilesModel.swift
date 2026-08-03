import Foundation

@MainActor
final class LargeFilesModel: ObservableObject {
    @Published var root: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published var minimumMB: Double = 100
    @Published var includeSystemLibrary = false
    @Published private(set) var files: [ScanItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0
    @Published private(set) var hasScanned = false
    @Published var failures: [Cleaner.Failure] = []

    private var task: Task<Void, Never>?

    var selectedSize: Int64 { files.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { files.filter(\.isSelected).count }

    func scan() {
        task?.cancel()
        isScanning = true
        hasScanned = false
        files = []
        failures = []
        scannedCount = 0

        let root = self.root
        let threshold = Int64(minimumMB * 1_048_576)
        let skipLibrary = !includeSystemLibrary

        task = Task { [weak self] in
            guard let self else { return }
            let stream = LargeFileFinder.stream(
                root: root,
                threshold: threshold,
                skipLibrary: skipLibrary
            )

            for await batch in stream {
                if Task.isCancelled { return }
                self.scannedCount = batch.visited
                if !batch.found.isEmpty {
                    self.files.append(contentsOf: batch.found)
                    self.files.sort { $0.size > $1.size }
                    if self.files.count > 500 { self.files.removeLast(self.files.count - 500) }
                }
            }

            if Task.isCancelled { return }
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

    func toggle(_ item: ScanItem) {
        guard let index = files.firstIndex(where: { $0.id == item.id }) else { return }
        files[index].isSelected.toggle()
    }

    func deselectAll() {
        for i in files.indices { files[i].isSelected = false }
    }

    func trashSelected() {
        let selected = files.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        let result = Cleaner.trash(selected)
        let removed = Set(selected.map(\.id))
        files.removeAll { removed.contains($0.id) && !FileManager.default.fileExists(atPath: $0.url.path) }
        failures = result.failures
        Task { await RemovalHistory.shared.add(source: .largeFiles, records: result.records) }
    }
}

/// Walks a directory tree and emits files above a size threshold as it goes,
/// so the UI can show results while the scan is still running.
enum LargeFileFinder {
    struct Batch {
        var found: [ScanItem]
        var visited: Int
    }

    static func stream(root: URL, threshold: Int64, skipLibrary: Bool) -> AsyncStream<Batch> {
        AsyncStream { continuation in
            let work = Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                let keys: [URLResourceKey] = [
                    .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .totalFileAllocatedSizeKey,
                    .contentModificationDateKey, .isDirectoryKey,
                ]
                // Hidden folders are where a dev machine actually hides its bulk
                // (~/.android AVDs, ~/.cache, ~/.docker), so they are walked too.
                var skipNames: Set<String> = [".Trash", "node_modules", ".git", "Photos Library.photoslibrary"]
                if skipLibrary { skipNames.insert("Library") }

                guard
                    let enumerator = fm.enumerator(
                        at: root,
                        includingPropertiesForKeys: keys,
                        options: [],
                        errorHandler: { _, _ in true }
                    )
                else {
                    continuation.finish()
                    return
                }

                var buffer: [ScanItem] = []
                var visited = 0

                // `for … in enumerator` is unavailable from an async context, so drive it by hand.
                while let next = enumerator.nextObject() {
                    guard let url = next as? URL else { continue }
                    if Task.isCancelled { break }
                    visited += 1

                    guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }

                    if values.isDirectory == true {
                        if skipNames.contains(url.lastPathComponent) {
                            enumerator.skipDescendants()
                        }
                        continue
                    }
                    guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }

                    let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                    if size >= threshold {
                        buffer.append(
                            ScanItem(
                                url: url,
                                displayName: url.lastPathComponent,
                                size: size,
                                modified: values.contentModificationDate,
                                isSelected: false
                            )
                        )
                    }

                    if visited % 4_000 == 0 {
                        continuation.yield(Batch(found: buffer, visited: visited))
                        buffer = []
                    }
                }

                continuation.yield(Batch(found: buffer, visited: visited))
                continuation.finish()
            }

            continuation.onTermination = { _ in work.cancel() }
        }
    }
}
