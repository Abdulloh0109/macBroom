import Foundation

@MainActor
final class ProcessesModel: ObservableObject {
    @Published private(set) var processes: [ProcessRecord] = []
    @Published private(set) var isLoading = false
    @Published var backgroundOnly = true
    @Published var query = ""
    @Published var failures: [Cleaner.Failure] = []

    var visible: [ProcessRecord] {
        processes
            .filter { !backgroundOnly || $0.isBackground }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var totalMemory: Int64 { visible.reduce(0) { $0 + $1.memory } }

    func loadIfNeeded() {
        guard processes.isEmpty, !isLoading else { return }
        reload()
    }

    func reload() {
        isLoading = true
        Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) { ProcessInventory.running() }.value
            guard let self else { return }
            self.processes = found
            self.isLoading = false
        }
    }

    func quit(_ record: ProcessRecord) {
        if ProcessInventory.quit(record) {
            processes.removeAll { $0.id == record.id }
        } else {
            failures = [
                Cleaner.Failure(path: record.name, reason: "The app refused to quit.")
            ]
        }
    }
}
