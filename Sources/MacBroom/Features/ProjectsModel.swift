import Foundation

/// One project with everything reclaimable inside it.
struct ProjectGroup: Identifiable {
    let id: String
    let name: String
    let url: URL
    var artifacts: [ProjectArtifact]

    var totalSize: Int64 { artifacts.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { artifacts.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var newestChange: Date? { artifacts.compactMap(\.modified).max() }
    var isStale: Bool {
        guard let newestChange else { return false }
        return Date().timeIntervalSince(newestChange) > 90 * 86_400
    }
}

@MainActor
final class ProjectsModel: ObservableObject {
    @Published var root: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published private(set) var groups: [ProjectGroup] = []
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var progress: Double = 0
    @Published var staleOnly = false
    @Published var failures: [Cleaner.Failure] = []

    private var task: Task<Void, Never>?

    var visible: [ProjectGroup] {
        staleOnly ? groups.filter(\.isStale) : groups
    }

    var totalSize: Int64 { visible.reduce(0) { $0 + $1.totalSize } }
    var selectedSize: Int64 { groups.reduce(0) { $0 + $1.selectedSize } }
    var selectedCount: Int {
        groups.reduce(0) { $0 + $1.artifacts.filter(\.isSelected).count }
    }

    func scan() {
        task?.cancel()
        isScanning = true
        hasScanned = false
        groups = []
        failures = []
        progress = 0

        let root = self.root
        task = Task { [weak self] in
            guard let self else { return }

            let discovered = await Task.detached(priority: .userInitiated) {
                ProjectScanner.discover(root: root)
            }.value
            if Task.isCancelled { return }

            guard !discovered.isEmpty else {
                self.finish(with: [])
                return
            }

            var sized: [ProjectArtifact] = []
            var done = 0

            await withTaskGroup(of: ProjectArtifact?.self) { group in
                let limit = 6
                var index = 0

                func submit() {
                    guard index < discovered.count else { return }
                    var artifact = discovered[index]
                    index += 1
                    group.addTask(priority: .userInitiated) {
                        artifact.size = SizeCalculator.size(of: artifact.url)
                        return artifact.size > 0 ? artifact : nil
                    }
                }
                for _ in 0..<min(limit, discovered.count) { submit() }

                while let result = await group.next() {
                    if Task.isCancelled { group.cancelAll(); return }
                    done += 1
                    if let artifact = result { sized.append(artifact) }
                    self.progress = Double(done) / Double(discovered.count)
                    submit()
                }
            }

            if Task.isCancelled { return }

            let byProject = Dictionary(grouping: sized) { $0.projectURL.path }
            let built = byProject.map { path, artifacts in
                ProjectGroup(
                    id: path,
                    name: artifacts[0].projectName,
                    url: artifacts[0].projectURL,
                    artifacts: artifacts.sorted { $0.size > $1.size }
                )
            }
            .sorted { $0.totalSize > $1.totalSize }

            self.finish(with: built)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isScanning = false
        hasScanned = true
    }

    private func finish(with groups: [ProjectGroup]) {
        self.groups = groups
        isScanning = false
        hasScanned = true
        progress = 1
    }

    // MARK: - Selection

    func toggle(_ artifact: ProjectArtifact) {
        for g in groups.indices {
            if let index = groups[g].artifacts.firstIndex(where: { $0.id == artifact.id }) {
                groups[g].artifacts[index].isSelected.toggle()
                return
            }
        }
    }

    func toggleProject(_ group: ProjectGroup) {
        guard let g = groups.firstIndex(where: { $0.id == group.id }) else { return }
        let turnOn = groups[g].artifacts.contains { !$0.isSelected }
        for index in groups[g].artifacts.indices {
            groups[g].artifacts[index].isSelected = turnOn
        }
    }

    func selectStale() {
        for g in groups.indices {
            let stale = groups[g].isStale
            for index in groups[g].artifacts.indices {
                groups[g].artifacts[index].isSelected = stale
            }
        }
    }

    func deselectAll() {
        for g in groups.indices {
            for index in groups[g].artifacts.indices {
                groups[g].artifacts[index].isSelected = false
            }
        }
    }

    // MARK: - Cleaning

    func trashSelected() {
        let selected = groups.flatMap { $0.artifacts.filter(\.isSelected) }
        guard !selected.isEmpty else { return }

        let items = selected.map {
            ScanItem(
                url: $0.url,
                displayName: $0.url.lastPathComponent,
                size: $0.size,
                modified: $0.modified,
                isSelected: true
            )
        }
        let result = Cleaner.trash(items)
        failures = result.failures
        Task { await RemovalHistory.shared.add(source: .projects, records: result.records) }

        let removed = Set(selected.map(\.id))
        var remaining: [ProjectGroup] = []
        for var group in groups {
            group.artifacts.removeAll {
                removed.contains($0.id) && !FileManager.default.fileExists(atPath: $0.url.path)
            }
            if !group.artifacts.isEmpty { remaining.append(group) }
        }
        groups = remaining
    }
}
