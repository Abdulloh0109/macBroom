import Foundation

@MainActor
final class ServicesModel: ObservableObject {
    @Published private(set) var services: [ServiceRecord] = []
    @Published private(set) var isLoading = false
    @Published var showApple = false
    @Published var query = ""
    @Published var failures: [Cleaner.Failure] = []

    var visible: [ServiceRecord] {
        services
            .filter { showApple || !$0.isApple }
            .filter {
                query.isEmpty
                    || $0.label.localizedCaseInsensitiveContains(query)
                    || $0.program.localizedCaseInsensitiveContains(query)
            }
    }

    var activeCount: Int { visible.count(where: \.isLoaded) }

    func loadIfNeeded() {
        guard services.isEmpty, !isLoading else { return }
        reload()
    }

    func reload() {
        isLoading = true
        Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) { ServiceInventory.all() }.value
            guard let self else { return }
            self.services = found
            self.isLoading = false
        }
    }

    func disable(_ service: ServiceRecord) {
        let result = ServiceInventory.disable(service)
        failures = result.failures
        if result.removed > 0 {
            services.removeAll { $0.id == service.id }
        }
    }
}

private extension Array {
    func count(where predicate: (Element) -> Bool) -> Int {
        reduce(0) { predicate($1) ? $0 + 1 : $0 }
    }
}
