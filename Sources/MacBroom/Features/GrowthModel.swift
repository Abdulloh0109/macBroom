import Foundation

@MainActor
final class GrowthModel: ObservableObject {
    @Published var root: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published private(set) var rows: [GrowthRow] = []
    @Published private(set) var isWatching = false
    @Published private(set) var elapsed = 0
    @Published private(set) var filesTouched = 0
    @Published private(set) var diskDelta: Int64 = 0

    private let watcher = GrowthWatcher()
    private var ticker: Task<Void, Never>?
    private var freeAtStart: Int64 = 0

    func start() {
        guard !isWatching else { return }
        freeAtStart = DiskInfo.current().available
        diskDelta = 0
        elapsed = 0
        rows = []
        filesTouched = 0
        watcher.start(root: root)
        isWatching = true

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self?.sample()
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        watcher.stop()
        isWatching = false
    }

    private func sample() {
        rows = watcher.rows()
        filesTouched = watcher.observedFiles
        // Free space going down is the headline; the folder list is the explanation.
        diskDelta = DiskInfo.current().available - freeAtStart
        if let started = watcher.startedAt {
            elapsed = Int(Date().timeIntervalSince(started))
        }
    }
}
