import Foundation

@MainActor
final class SystemDataModel: ObservableObject {
    @Published private(set) var entries: [SystemDataEntry] = []
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var snapshotCount = 0
    @Published var disk = DiskInfo.current()
    @Published var justCopied: String?

    private var task: Task<Void, Never>?

    var measuredTotal: Int64 { entries.reduce(0) { $0 + $1.size } }

    func scanIfNeeded() {
        guard entries.isEmpty, !isScanning else { return }
        scan()
    }

    func scan() {
        task?.cancel()
        isScanning = true
        hasScanned = false
        progress = 0
        disk = DiskInfo.current()

        task = Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) {
                SystemDataScanner.entries().filter(\.exists)
            }.value
            guard let self, !Task.isCancelled else { return }

            self.entries = found
            self.snapshotCount = await Task.detached(priority: .utility) {
                SystemDataScanner.snapshotCount()
            }.value

            // Measuring /Library and friends is the slow part, so sizes land one
            // at a time rather than after a single long wait.
            var done = 0
            await withTaskGroup(of: (String, Int64).self) { group in
                for entry in found {
                    group.addTask(priority: .utility) {
                        (entry.id, SizeCalculator.size(of: URL(fileURLWithPath: entry.path)))
                    }
                }
                while let (id, size) = await group.next() {
                    if Task.isCancelled { group.cancelAll(); return }
                    done += 1
                    if let index = self.entries.firstIndex(where: { $0.id == id }) {
                        self.entries[index].size = size
                    }
                    // Sorting only at the end: re-ordering while sizes arrive makes
                    // the list jump under the reader's eyes.
                    self.progress = Double(done) / Double(max(found.count, 1))
                }
            }

            self.entries.sort { $0.size > $1.size }
            self.isScanning = false
            self.hasScanned = true
            self.disk = DiskInfo.current()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isScanning = false
        hasScanned = true
    }

    func copy(_ command: String, id: String) {
        Clipboard.copy(command)
        justCopied = id
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if self?.justCopied == id { self?.justCopied = nil }
        }
    }
}
