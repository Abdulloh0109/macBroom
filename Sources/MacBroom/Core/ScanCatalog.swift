import Foundation

/// Where MacBroom looks for junk, and how it turns each location into candidate items.
struct ScanRule {
    enum Mode {
        /// Every direct child of `path` becomes its own item.
        case children
        /// `path` itself is one item.
        case itself
        /// Files directly inside `path` with a matching extension, older than `days`.
        case staleFiles(days: Int, extensions: Set<String>)
    }

    let category: CategoryID
    let path: String
    let mode: Mode
    var label: String? = nil
    var skip: Set<String> = []
}

enum ScanCatalog {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    private static func h(_ suffix: String) -> String { home + "/" + suffix }

    static let rules: [ScanRule] = [
        // ── Developer caches ────────────────────────────────────────────────
        .init(category: .devCaches, path: h(".npm/_cacache"), mode: .itself, label: "npm cache"),
        .init(category: .devCaches, path: h("Library/Caches/Yarn"), mode: .itself, label: "Yarn cache"),
        .init(category: .devCaches, path: h(".yarn/berry/cache"), mode: .itself, label: "Yarn Berry cache"),
        .init(category: .devCaches, path: h("Library/pnpm/store"), mode: .itself, label: "pnpm store"),
        .init(category: .devCaches, path: h(".bun/install/cache"), mode: .itself, label: "Bun cache"),
        .init(category: .devCaches, path: h("Library/Caches/deno"), mode: .itself, label: "Deno cache"),
        .init(category: .devCaches, path: h("Library/Caches/CocoaPods"), mode: .itself, label: "CocoaPods cache"),
        .init(category: .devCaches, path: h("Library/Caches/Homebrew"), mode: .itself, label: "Homebrew downloads"),
        .init(category: .devCaches, path: h("Library/Caches/pip"), mode: .itself, label: "pip cache"),
        .init(category: .devCaches, path: h("Library/Caches/typescript"), mode: .itself, label: "TypeScript cache"),
        .init(category: .devCaches, path: h("Library/Caches/ms-playwright"), mode: .itself, label: "Playwright browsers"),
        .init(category: .devCaches, path: h(".gradle/caches"), mode: .itself, label: "Gradle cache"),
        .init(category: .devCaches, path: h(".cargo/registry/cache"), mode: .itself, label: "Cargo registry cache"),
        .init(category: .devCaches, path: h("go/pkg/mod/cache/download"), mode: .itself, label: "Go module cache"),
        .init(category: .devCaches, path: h(".cache"), mode: .children),

        // ── Xcode ───────────────────────────────────────────────────────────
        .init(category: .xcode, path: h("Library/Developer/Xcode/DerivedData"), mode: .children),
        .init(category: .xcode, path: h("Library/Developer/Xcode/iOS DeviceSupport"), mode: .children),
        .init(category: .xcode, path: h("Library/Developer/Xcode/watchOS DeviceSupport"), mode: .children),
        .init(category: .xcode, path: h("Library/Developer/Xcode/tvOS DeviceSupport"), mode: .children),
        .init(category: .xcode, path: h("Library/Developer/CoreSimulator/Caches"), mode: .itself, label: "Simulator caches"),
        .init(category: .xcode, path: h("Library/Caches/com.apple.dt.Xcode"), mode: .itself, label: "Xcode cache"),
        .init(category: .xcode, path: h("Library/Developer/XCTestDevices"), mode: .children),

        // ── Browsers ────────────────────────────────────────────────────────
        .init(category: .browsers, path: h("Library/Caches/Google/Chrome"), mode: .itself, label: "Chrome cache"),
        .init(category: .browsers, path: h("Library/Caches/com.apple.Safari"), mode: .itself, label: "Safari cache"),
        .init(category: .browsers, path: h("Library/Caches/Firefox"), mode: .itself, label: "Firefox cache"),
        .init(category: .browsers, path: h("Library/Caches/BraveSoftware"), mode: .itself, label: "Brave cache"),
        .init(category: .browsers, path: h("Library/Caches/Microsoft Edge"), mode: .itself, label: "Edge cache"),
        .init(category: .browsers, path: h("Library/Caches/company.thebrowser.Browser"), mode: .itself, label: "Arc cache"),

        // ── Mail ────────────────────────────────────────────────────────────
        .init(
            category: .mail,
            path: h("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
            mode: .children
        ),

        // ── Logs ────────────────────────────────────────────────────────────
        .init(category: .appLogs, path: h("Library/Logs"), mode: .children, skip: ["DiagnosticReports"]),
        .init(category: .appLogs, path: h("Library/Application Support/CrashReporter"), mode: .children),

        // ── Generic user caches (runs last so the specific rules win) ───────
        .init(
            category: .userCaches,
            path: h("Library/Caches"),
            mode: .children,
            // Managed by the system / not reclaimable in a meaningful way.
            skip: ["com.apple.containermanagerd", "com.apple.rosetta.update", "CloudKit"]
        ),

        // ── Trash ───────────────────────────────────────────────────────────
        .init(category: .trash, path: h(".Trash"), mode: .children),

        // ── Review-first categories ─────────────────────────────────────────
        .init(category: .iosBackups, path: h("Library/Application Support/MobileSync/Backup"), mode: .children),
        .init(
            category: .oldDownloads,
            path: h("Downloads"),
            mode: .staleFiles(days: 60, extensions: ["dmg", "pkg", "iso", "zip", "xip", "msi"])
        ),
    ]

    struct Candidate {
        let category: CategoryID
        let url: URL
        let displayName: String
    }

    /// Expands the rules into concrete paths that exist on this machine.
    ///
    /// Rules overlap on purpose (`~/Library/Caches/Google/Chrome` is a browser cache,
    /// `~/Library/Caches/Google` is a generic user cache). Overlaps must never produce
    /// two candidates covering the same bytes, or the totals lie and cleaning one
    /// makes the other fail. Earlier, more specific rules win; a later rule that
    /// contains an already-claimed path is split into its children instead.
    static func candidates() -> [Candidate] {
        let fm = FileManager.default
        var seen = Set<String>()
        var result: [Candidate] = []

        func append(_ category: CategoryID, _ url: URL, _ name: String, depth: Int = 0) {
            let std = url.standardizedFileURL
            let path = std.path
            guard SafetyGuard.isRemovable(std), !seen.contains(path) else { return }

            // Already covered by a claimed ancestor.
            if seen.contains(where: { path.hasPrefix($0 + "/") }) { return }

            // Contains a claimed descendant — descend so the bytes are counted once.
            if depth < 3, seen.contains(where: { $0.hasPrefix(path + "/") }) {
                let children = (try? fm.contentsOfDirectory(at: std, includingPropertiesForKeys: nil)) ?? []
                for child in children {
                    append(category, child, name + "/" + child.lastPathComponent, depth: depth + 1)
                }
                return
            }

            seen.insert(path)
            result.append(Candidate(category: category, url: std, displayName: name))
        }

        for rule in rules {
            let root = URL(fileURLWithPath: rule.path)
            guard fm.fileExists(atPath: root.path) else { continue }

            switch rule.mode {
            case .itself:
                append(rule.category, root, rule.label ?? root.lastPathComponent)

            case .children:
                let children =
                    (try? fm.contentsOfDirectory(
                        at: root,
                        includingPropertiesForKeys: nil,
                        options: []
                    )) ?? []
                for child in children where !rule.skip.contains(child.lastPathComponent) {
                    append(rule.category, child, child.lastPathComponent)
                }

            case .staleFiles(let days, let extensions):
                let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
                let children =
                    (try? fm.contentsOfDirectory(
                        at: root,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    )) ?? []
                for child in children {
                    guard extensions.contains(child.pathExtension.lowercased()) else { continue }
                    guard let modified = SizeCalculator.modificationDate(of: child), modified < cutoff else { continue }
                    append(rule.category, child, child.lastPathComponent)
                }
            }
        }

        return result
    }
}
