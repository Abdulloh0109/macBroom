import AppKit
import Foundation

/// Removal is always "move to Trash", never `unlink`. If MacBroom gets something
/// wrong the user can put it back — that is the whole safety story.
enum Cleaner {
    struct Failure: Identifiable {
        let id = UUID()
        let path: String
        let reason: String
    }

    struct Result {
        var freed: Int64 = 0
        var removed: Int = 0
        var failures: [Failure] = []
    }

    /// Moves each item to the Trash after re-checking it against `SafetyGuard`.
    static func trash(_ items: [ScanItem]) -> Result {
        var result = Result()
        let fm = FileManager.default

        for item in items {
            do {
                try SafetyGuard.assertRemovable(item.url)
                guard fm.fileExists(atPath: item.url.path) else { continue }
                try fm.trashItem(at: item.url, resultingItemURL: nil)
                result.freed += item.size
                result.removed += 1
            } catch {
                result.failures.append(
                    Failure(path: item.url.path, reason: error.localizedDescription)
                )
            }
        }
        return result
    }

    /// Empties the Trash for real. Separate call so it is always an explicit choice.
    static func emptyTrash() -> Result {
        var result = Result()
        let fm = FileManager.default
        let trash = SafetyGuard.home.appendingPathComponent(".Trash")
        let children = (try? fm.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil)) ?? []

        for child in children {
            let size = SizeCalculator.size(of: child)
            do {
                try SafetyGuard.assertRemovable(child)
                try fm.removeItem(at: child)
                result.freed += size
                result.removed += 1
            } catch {
                result.failures.append(Failure(path: child.path, reason: error.localizedDescription))
            }
        }
        return result
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
