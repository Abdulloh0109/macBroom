import Foundation

@MainActor
final class HistoryModel: ObservableObject {
    @Published private(set) var sessions: [RemovalSession] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published var expanded: Set<UUID> = []

    var totalFreed: Int64 { sessions.reduce(0) { $0 + $1.freed } }
    var restorableTotal: Int { sessions.reduce(0) { $0 + $1.restorableCount } }

    func load() {
        isLoading = true
        Task { [weak self] in
            let all = await RemovalHistory.shared.all()
            guard let self else { return }
            self.sessions = all
            self.isLoading = false
        }
    }

    func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    func restore(_ record: RemovalRecord) {
        Task { [weak self] in
            let outcome = await RemovalHistory.shared.restore(record)
            guard let self else { return }
            if case .failure(let error) = outcome {
                self.lastError = error.message(Localized.current)
            } else {
                self.lastError = nil
            }
            self.load()
        }
    }

    func restoreAll(in session: RemovalSession) {
        Task { [weak self] in
            var failure: String?
            // Deepest paths first: a parent folder restored before its child would
            // occupy the child's destination.
            for record in session.records.sorted(by: { $0.originalPath.count > $1.originalPath.count }) {
                if case .failure(let error) = await RemovalHistory.shared.restore(record),
                    failure == nil
                {
                    failure = error.message(Localized.current)
                }
            }
            guard let self else { return }
            self.lastError = failure
            self.load()
        }
    }

    func forget(_ session: RemovalSession) {
        Task { [weak self] in
            await RemovalHistory.shared.forget(session.id)
            self?.load()
        }
    }

    func clear() {
        Task { [weak self] in
            await RemovalHistory.shared.clear()
            self?.load()
        }
    }
}
