import Foundation

/// Read-only terminal mode: `MacBroom --scan [--json]`.
/// Reports what the GUI would offer to clean. It never removes anything —
/// deletion always requires the confirmation step in the app.
enum CLIRunner {
    static func runIfRequested() {
        let args = CommandLine.arguments
        if args.contains("--selftest") { selfTest() }
        if let index = args.firstIndex(of: "--map") {
            let target = index + 1 < args.count ? args[index + 1] : NSHomeDirectory()
            mapReport(URL(fileURLWithPath: target))
        }
        guard args.contains("--scan") else { return }
        let asJSON = args.contains("--json")

        let candidates = ScanCatalog.candidates()
        var sizes = [Int64](repeating: 0, count: candidates.count)
        sizes.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: candidates.count) { index in
                buffer[index] = SizeCalculator.size(of: candidates[index].url)
            }
        }

        var buckets: [CategoryID: [(String, Int64, String)]] = [:]
        for (index, candidate) in candidates.enumerated() where sizes[index] > 0 {
            buckets[candidate.category, default: []]
                .append((candidate.displayName, sizes[index], candidate.url.path))
        }

        let disk = DiskInfo.current()
        let total = sizes.reduce(0, +)

        // `--uz` / `--en` override the language the report is printed in.
        let language: Language =
            args.contains("--en") ? .en : (args.contains("--uz") ? .uz : Localized.current)
        Localized.current = language
        let uz = language == .uz

        if asJSON {
            var payload: [String: Any] = [
                "diskTotal": disk.total,
                "diskAvailable": disk.available,
                "diskPurgeable": disk.purgeable,
                "reclaimableBytes": total,
            ]
            payload["categories"] = CategoryID.displayOrder.compactMap { id -> [String: Any]? in
                guard let items = buckets[id] else { return nil }
                return [
                    "id": id.rawValue,
                    // Must be a String: a `T` here makes JSONSerialization throw, and the
                    // `try?` below would swallow it into silent empty output.
                    "title": id.title(language),
                    "risk": id.risk.rawValue,
                    "bytes": items.reduce(0) { $0 + $1.1 },
                    "items": items.sorted { $0.1 > $1.1 }.map { ["name": $0.0, "bytes": $0.1, "path": $0.2] },
                ]
            }
            do {
                let data = try JSONSerialization.data(
                    withJSONObject: payload,
                    options: [.prettyPrinted, .sortedKeys]
                )
                print(String(decoding: data, as: UTF8.self))
            } catch {
                FileHandle.standardError.write(Data("json failed: \(error)\n".utf8))
                exit(1)
            }
            exit(0)
        }

        /// Pads by display width so the columns line up with non-ASCII titles.
        func pad(_ text: String, _ width: Int) -> String {
            text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
        }

        let rule = "  " + String(repeating: "─", count: 66)
        print("")
        print(uz ? "  MacBroom — hisobot (hech narsa o'chirilmadi)" : "  MacBroom — scan report (nothing was removed)")
        print(
            uz
                ? "  Disk: \(Format.bytes(disk.total)) dan \(Format.bytes(disk.used)) band, \(Format.bytes(disk.available)) bo'sh"
                : "  Disk: \(Format.bytes(disk.used)) used of \(Format.bytes(disk.total)), \(Format.bytes(disk.available)) free"
        )
        if disk.purgeable > 1_000_000_000 {
            print(
                uz
                    ? "  Yana \(Format.bytes(disk.purgeable)) ni macOS kerak bo'lganda o'zi bo'shatadi"
                    : "  A further \(Format.bytes(disk.purgeable)) is purgeable by macOS on demand"
            )
        }
        print(rule)

        for id in CategoryID.displayOrder {
            guard let items = buckets[id], !items.isEmpty else { continue }
            let subtotal = items.reduce(0) { $0 + $1.1 }
            let flag = id.risk == .safe ? S.riskSafe(language) : S.riskReview(language)
            print(
                "  " + pad(id.title(language), 28)
                    + pad(Format.bytes(subtotal), 12)
                    + pad(S.items(items.count)(language), 12)
                    + "[\(flag)]"
            )
            for (name, size, _) in items.sorted(by: { $0.1 > $1.1 }).prefix(3) {
                print("      · \(name) — \(Format.bytes(size))")
            }
        }

        print(rule)
        print((uz ? "  Bo'shatish mumkin: " : "  Reclaimable: ") + Format.bytes(total))
        print("")
        exit(0)
    }

    /// `MacBroom --map [path]` — the Disk Map's numbers, on the terminal.
    /// Same tree the GUI draws, so it doubles as a way to check them against `du`.
    private static func mapReport(_ root: URL) {
        let started = Date()
        let tree = DiskMapTree.build(root: root)
        let elapsed = Date().timeIntervalSince(started)
        let total = tree.size(of: tree.root)

        print("")
        print("  \(tree.root)")
        print("  \(Format.bytes(total)) · \(tree.fileCount) files · \(String(format: "%.1f", elapsed))s")
        print("  " + String(repeating: "─", count: 60))

        for node in tree.nodes(under: tree.root).prefix(15) {
            let share = total > 0 ? Double(node.size) / Double(total) * 100 : 0
            let bar = String(repeating: "█", count: max(0, Int(share / 3)))
            let name = node.name.count > 28 ? String(node.name.prefix(27)) + "…" : node.name
            print(
                "  " + name.padding(toLength: 28, withPad: " ", startingAt: 0)
                    + Format.bytes(node.size).padding(toLength: 11, withPad: " ", startingAt: 0)
                    + String(format: "%5.1f%%  ", share) + bar
            )
        }
        print("")
        exit(0)
    }

    /// Verifies the guard that stands between MacBroom and your files.
    private static func selfTest() {
        let home = SafetyGuard.home.path
        var failures = 0

        func check(_ path: String, shouldAllow: Bool) {
            let allowed = SafetyGuard.isRemovable(URL(fileURLWithPath: path))
            let ok = allowed == shouldAllow
            if !ok { failures += 1 }
            let verdict = allowed ? "allow" : "refuse"
            print("  \(ok ? "✓" : "✗ FAIL")  \(verdict.padding(toLength: 6, withPad: " ", startingAt: 0))  \(path)")
        }

        print("\n  SafetyGuard self-test\n  " + String(repeating: "─", count: 62))

        // Must always be refused.
        for path in [
            "/", "/System", "/System/Library", "/Library", "/Users", "/usr/bin", "/etc", "/private/var",
            "/Applications", home, home + "/Documents", home + "/Desktop", home + "/Downloads",
            home + "/Library", home + "/Library/Caches", home + "/Library/Preferences",
            home + "/Library/Application Support", home + "/Library/Containers", home + "/Library/Keychains",
            home + "/.ssh", home + "/.Trash", home + "/Library/Developer/CoreSimulator/Devices",
            "/Users/someone-else/Documents", "/Volumes/Backup",
        ] {
            check(path, shouldAllow: false)
        }

        // Must be allowed.
        for path in [
            home + "/Library/Caches/com.example.app",
            home + "/Library/Caches/Google/Chrome",
            home + "/Library/Logs/SomeApp",
            home + "/Library/Developer/Xcode/DerivedData/Foo-abc123",
            home + "/.Trash/old-file.zip",
            home + "/Downloads/installer.dmg",
            "/Applications/Example.app",
        ] {
            check(path, shouldAllow: true)
        }

        print("  " + String(repeating: "─", count: 62))
        print(failures == 0 ? "  All checks passed\n" : "  \(failures) check(s) FAILED\n")
        exit(failures == 0 ? 0 : 1)
    }
}
