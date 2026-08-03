import Foundation

@MainActor
final class ChangesModel: ObservableObject {
    @Published var root: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published private(set) var checkpoints: [CheckpointMeta] = []
    @Published private(set) var comparison: DiskComparison?
    @Published private(set) var isScanning = false
    @Published private(set) var scannedFiles = 0
    @Published private(set) var scannedBytes: Int64 = 0
    /// The older of the two checkpoints being compared; the newest is the other side.
    @Published var baseline: UUID? {
        didSet { if baseline != oldValue { compare() } }
    }
    @Published private(set) var mismatch = false

    private var task: Task<Void, Never>?

    /// Checkpoints of the folder currently selected — only those can be compared.
    var comparable: [CheckpointMeta] {
        checkpoints.filter { $0.root == root.standardizedFileURL.path }
    }

    var latest: CheckpointMeta? { comparable.first }

    func load() {
        Task { [weak self] in
            let all = await CheckpointStore.shared.index()
            guard let self else { return }
            self.checkpoints = all
            // Default to the previous checkpoint: "what changed since last time" is
            // the question this screen exists to answer.
            if self.baseline == nil || !self.comparable.contains(where: { $0.id == self.baseline }) {
                self.baseline = self.comparable.dropFirst().first?.id
            } else {
                self.compare()
            }
        }
    }

    /// Measures the folder now and keeps the result.
    func take() {
        guard !isScanning else { return }
        task?.cancel()
        isScanning = true
        scannedFiles = 0
        scannedBytes = 0

        let root = self.root
        task = Task { [weak self] in
            guard let self else { return }
            let tree = await Task.detached(priority: .userInitiated) { () -> DiskMapTree in
                DiskMapTree.build(root: root) { progress in
                    Task { @MainActor [weak self] in
                        self?.scannedFiles = progress.files
                        self?.scannedBytes = progress.bytes
                    }
                }
            }.value

            if Task.isCancelled { return }
            let checkpoint = DiskCheckpoint.make(from: tree)
            await CheckpointStore.shared.save(checkpoint)
            self.isScanning = false
            // The one just taken becomes the newest side, so the previous newest
            // is what it should be measured against.
            self.baseline = nil
            self.load()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isScanning = false
    }

    func delete(_ meta: CheckpointMeta) {
        Task { [weak self] in
            await CheckpointStore.shared.delete(meta.id)
            guard let self else { return }
            if self.baseline == meta.id { self.baseline = nil }
            self.load()
        }
    }

    func compare() {
        guard let newest = latest, let baseline, baseline != newest.id else {
            comparison = nil
            mismatch = false
            return
        }
        Task { [weak self] in
            let older = await CheckpointStore.shared.load(baseline)
            let newer = await CheckpointStore.shared.load(newest.id)
            guard let self else { return }
            guard let older, let newer else {
                self.comparison = nil
                self.mismatch = true
                return
            }
            self.comparison = DiskComparison.between(older, newer)
            self.mismatch = self.comparison == nil
        }
    }
}
