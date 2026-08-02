import Foundation

/// Backs both the "Installed Apps" and "Hidden Apps" screens — same inventory,
/// different filter, so the expensive scan happens once.
@MainActor
final class AppsModel: ObservableObject {
    @Published private(set) var apps: [AppRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    @Published var query = ""
    @Published var selected: AppRecord?
    @Published private(set) var leftovers: [Leftover] = []
    @Published private(set) var isLoadingLeftovers = false
    @Published var failures: [Cleaner.Failure] = []

    private var loadTask: Task<Void, Never>?

    func visible(hidden: Bool) -> [AppRecord] {
        apps
            .filter { $0.isHidden == hidden }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    func totalSize(hidden: Bool) -> Int64 {
        visible(hidden: hidden).reduce(0) { $0 + $1.size }
    }

    var leftoverSize: Int64 { leftovers.filter(\.isSelected).reduce(0) { $0 + $1.size } }

    func loadIfNeeded() {
        guard apps.isEmpty, !isLoading else { return }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        isLoading = true
        progress = 0

        loadTask = Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) { AppInventory.all() }.value
            guard let self, !Task.isCancelled else { return }
            self.apps = found

            // Sizing every bundle is the slow part, so it streams in afterwards.
            var done = 0
            await withTaskGroup(of: (String, Int64).self) { group in
                let limit = 6
                var index = 0

                func submit() {
                    guard index < found.count else { return }
                    let app = found[index]
                    index += 1
                    group.addTask(priority: .utility) {
                        (app.id, SizeCalculator.size(of: app.url))
                    }
                }
                for _ in 0..<min(limit, found.count) { submit() }

                while let (id, size) = await group.next() {
                    if Task.isCancelled { group.cancelAll(); return }
                    done += 1
                    if let position = self.apps.firstIndex(where: { $0.id == id }) {
                        self.apps[position].size = size
                    }
                    self.progress = found.isEmpty ? 1 : Double(done) / Double(found.count)
                    submit()
                }
            }

            self.isLoading = false
        }
    }

    func select(_ app: AppRecord) {
        selected = app
        leftovers = []
        failures = []
        isLoadingLeftovers = true

        Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) {
                AppInventory.leftovers(for: app)
            }.value
            guard let self, self.selected?.id == app.id else { return }
            self.leftovers = found
            self.isLoadingLeftovers = false
        }
    }

    func toggleLeftover(_ leftover: Leftover) {
        guard let index = leftovers.firstIndex(where: { $0.id == leftover.id }) else { return }
        leftovers[index].isSelected.toggle()
    }

    func uninstall() {
        guard let app = selected, app.isRemovable else { return }

        var targets = [
            ScanItem(url: app.url, displayName: app.name, size: app.size, modified: nil, isSelected: true)
        ]
        targets += leftovers.filter(\.isSelected).map {
            ScanItem(
                url: $0.url,
                displayName: $0.url.lastPathComponent,
                size: $0.size,
                modified: nil,
                isSelected: true
            )
        }

        let result = Cleaner.trash(targets)
        failures = result.failures
        if !FileManager.default.fileExists(atPath: app.url.path) {
            apps.removeAll { $0.id == app.id }
            selected = nil
            leftovers = []
        }
    }
}
