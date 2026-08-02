import AppKit
import Foundation

/// What the progress line is saying right now. Kept as state rather than a
/// baked string so switching language re-renders it immediately.
enum ScanProgress {
    case idle
    case searching
    case measuring(done: Int, total: Int)
    case complete
    case nothingFound
    case cancelled
    case cleaning(count: Int)
    case freed(bytes: Int64)

    func label(_ language: Language) -> String {
        switch self {
        case .idle: return ""
        case .searching: return S.searchingJunk(language)
        case .measuring(let done, let total): return S.measuring(done, total)(language)
        case .complete: return S.scanComplete(language)
        case .nothingFound: return S.nothingToClean(language)
        case .cancelled: return S.stop(language)
        case .cleaning(let count): return S.movingToTrash(count)(language)
        case .freed(let bytes): return S.freed(Format.bytes(bytes))(language)
        }
    }
}

@MainActor
final class SmartScanModel: ObservableObject {
    @Published private(set) var categories: [ScanCategory] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var progressState: ScanProgress = .idle
    @Published private(set) var lastFreed: Int64 = 0
    @Published var failures: [Cleaner.Failure] = []
    @Published var disk = DiskInfo.current()

    private var scanTask: Task<Void, Never>?

    var foundSize: Int64 { categories.totalSize }
    var selectedSize: Int64 { categories.selectedSize }
    var selectedCount: Int { categories.selectedCount }

    // MARK: - Scanning

    func scan() {
        guard !isScanning else { return }
        scanTask?.cancel()
        isScanning = true
        hasScanned = false
        lastFreed = 0
        failures = []
        categories = []
        progress = 0
        progressState = .searching

        scanTask = Task { [weak self] in
            guard let self else { return }

            let candidates = await Task.detached(priority: .userInitiated) {
                ScanCatalog.candidates()
            }.value

            // Cache folders are usually named after a bundle id, so a running app
            // can be matched to its own cache and flagged "close it first".
            let openApps = await Task.detached(priority: .userInitiated) {
                Set(
                    NSWorkspace.shared.runningApplications
                        .compactMap(\.bundleIdentifier)
                        .map { $0.lowercased() }
                )
            }.value

            if Task.isCancelled { return }
            guard !candidates.isEmpty else {
                self.finishScan(with: [])
                return
            }

            var buckets: [CategoryID: [ScanItem]] = [:]
            var done = 0

            // Bounded concurrency: sizing is IO bound, but an unbounded fan-out
            // over hundreds of cache folders just thrashes the disk.
            await withTaskGroup(of: (CategoryID, ScanItem)?.self) { group in
                let limit = 6
                var index = 0

                func submit() {
                    guard index < candidates.count else { return }
                    let candidate = candidates[index]
                    index += 1
                    group.addTask(priority: .userInitiated) {
                        let size = SizeCalculator.size(of: candidate.url)
                        guard size > 0 else { return nil }
                        let name = candidate.displayName.lowercased()
                        let inUse = openApps.contains(name)
                        let item = ScanItem(
                            url: candidate.url,
                            displayName: candidate.displayName,
                            size: size,
                            modified: SizeCalculator.modificationDate(of: candidate.url),
                            isSelected: candidate.category.risk == .safe,
                            advice: inUse ? .inUse : .removable
                        )
                        return (candidate.category, item)
                    }
                }

                for _ in 0..<min(limit, candidates.count) { submit() }

                while let result = await group.next() {
                    if Task.isCancelled { group.cancelAll(); return }
                    done += 1
                    if let (category, item) = result {
                        buckets[category, default: []].append(item)
                    }
                    self.progress = Double(done) / Double(candidates.count)
                    self.progressState = .measuring(done: done, total: candidates.count)
                    submit()
                }
            }

            if Task.isCancelled { return }

            let built = CategoryID.displayOrder.compactMap { id -> ScanCategory? in
                guard let items = buckets[id], !items.isEmpty else { return nil }
                return ScanCategory(id: id, items: items.sorted { $0.size > $1.size })
            }
            self.finishScan(with: built)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        progressState = .cancelled
    }

    private func finishScan(with categories: [ScanCategory]) {
        self.categories = categories
        isScanning = false
        hasScanned = true
        progress = 1
        progressState = categories.isEmpty ? .nothingFound : .complete
        disk = DiskInfo.current()
    }

    // MARK: - Selection

    func setSelection(_ selected: Bool, category: CategoryID) {
        guard let index = categories.firstIndex(where: { $0.id == category }) else { return }
        for i in categories[index].items.indices {
            categories[index].items[i].isSelected = selected
        }
    }

    func toggleItem(_ item: ScanItem) {
        for c in categories.indices {
            if let i = categories[c].items.firstIndex(where: { $0.id == item.id }) {
                categories[c].items[i].isSelected.toggle()
                return
            }
        }
    }

    func toggleExpanded(_ category: CategoryID) {
        guard let index = categories.firstIndex(where: { $0.id == category }) else { return }
        categories[index].isExpanded.toggle()
    }

    func selectAllSafe() {
        for c in categories.indices {
            let selected = categories[c].id.risk == .safe
            for i in categories[c].items.indices {
                categories[c].items[i].isSelected = selected
            }
        }
    }

    func deselectAll() {
        for c in categories.indices {
            for i in categories[c].items.indices {
                categories[c].items[i].isSelected = false
            }
        }
    }

    // MARK: - Cleaning

    func cleanSelected() {
        guard !isCleaning else { return }
        let selected = categories.flatMap { $0.items.filter(\.isSelected) }
        guard !selected.isEmpty else { return }

        isCleaning = true
        progressState = .cleaning(count: selected.count)

        Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .userInitiated) {
                Cleaner.trash(selected)
            }.value

            let removedIDs = Set(selected.map(\.id))
            var remaining: [ScanCategory] = []
            for var category in self.categories {
                category.items.removeAll { removedIDs.contains($0.id) }
                if !category.items.isEmpty { remaining.append(category) }
            }

            self.categories = remaining
            self.lastFreed = result.freed
            self.failures = result.failures
            self.isCleaning = false
            self.progressState = .freed(bytes: result.freed)
            self.disk = DiskInfo.current()
        }
    }

    func progressLabel(_ language: Language) -> String { progressState.label(language) }

    func refreshDisk() {
        disk = DiskInfo.current()
    }
}
