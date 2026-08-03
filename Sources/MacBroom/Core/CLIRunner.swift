import Foundation

/// Read-only terminal mode: `MacBroom --scan [--json]`.
/// Reports what the GUI would offer to clean. It never removes anything —
/// deletion always requires the confirmation step in the app.
enum CLIRunner {
    static func runIfRequested() {
        let args = CommandLine.arguments
        if args.contains("--selftest") { selfTest() }
        if args.contains("--undotest") { undoTest() }
        if args.contains("--growthtest") { growthTest() }
        if args.contains("--historytest") {
            historyTest(keep: args.contains("keep"), restoreOnly: args.contains("restore"))
        }
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

        // `--lang <code>` (or the bare `--uz` / `--en` shorthands) overrides the
        // language the report is printed in.
        let language: Language = {
            if let index = args.firstIndex(of: "--lang"), index + 1 < args.count,
                let picked = Language(rawValue: args[index + 1].lowercased())
            {
                return picked
            }
            for candidate in Language.allCases where args.contains("--" + candidate.rawValue) {
                return candidate
            }
            return Localized.current
        }()
        Localized.current = language

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

        /// Terminal columns a string occupies. CJK ideographs are drawn two cells
        /// wide, so counting characters misaligns every Chinese and Japanese row.
        func displayWidth(_ text: String) -> Int {
            text.unicodeScalars.reduce(0) { total, scalar in
                let v = scalar.value
                let wide =
                    (0x1100...0x115F).contains(v) || (0x2E80...0xA4CF).contains(v)
                    || (0xAC00...0xD7A3).contains(v) || (0xF900...0xFAFF).contains(v)
                    || (0xFE30...0xFE6F).contains(v) || (0xFF00...0xFF60).contains(v)
                    || (0xFFE0...0xFFE6).contains(v) || (0x20000...0x3FFFD).contains(v)
                return total + (wide ? 2 : 1)
            }
        }

        /// Pads to a column width, always leaving at least one space between columns.
        func pad(_ text: String, _ width: Int) -> String {
            let gap = max(1, width - displayWidth(text))
            return text + String(repeating: " ", count: gap)
        }

        let rule = "  " + String(repeating: "─", count: 66)
        print("")
        print("  " + S.cliHeader(language))
        print(
            "  "
                + S.cliDisk(
                    Format.bytes(disk.total),
                    Format.bytes(disk.used),
                    Format.bytes(disk.available)
                )(language)
        )
        if disk.purgeable > 1_000_000_000 {
            print("  " + S.cliPurgeable(Format.bytes(disk.purgeable))(language))
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
        print("  " + S.cliReclaimable(Format.bytes(total))(language))
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

    /// `MacBroom --growthtest` — writes known amounts and checks the watcher's
    /// arithmetic. The byte deltas are the whole value of the feature, so they are
    /// measured against files of known size rather than eyeballed.
    private static func growthTest() {
        let fm = FileManager.default
        let folder = SafetyGuard.home
            .appendingPathComponent("Library/Caches/macbroom-growth-test", isDirectory: true)
        let file = folder.appendingPathComponent("big.bin")
        let megabyte = 1_048_576
        var failures = 0

        func check(_ label: String, _ passed: Bool, _ detail: String = "") {
            if !passed { failures += 1 }
            print("  \(passed ? "✓" : "✗ FAIL")  \(label)\(detail.isEmpty ? "" : "  (\(detail))")")
        }

        func settle(_ seconds: Double) {
            Thread.sleep(forTimeInterval: seconds)
        }

        /// Allocation rounds up, so exact equality would be a flaky assertion.
        func near(_ actual: Int64, _ expectedMB: Int, tolerance: Int = 3) -> Bool {
            abs(actual - Int64(expectedMB * megabyte)) < Int64(tolerance * megabyte)
        }

        print("\n  Growth watcher\n  " + String(repeating: "─", count: 62))

        try? fm.removeItem(at: folder)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let watcher = GrowthWatcher()
        watcher.start(root: SafetyGuard.home.appendingPathComponent("Library/Caches"))
        settle(1.5)

        try? Data(repeating: 7, count: 20 * megabyte).write(to: file)
        settle(2.5)
        var row = watcher.rows().first { $0.path == folder.path }
        check(
            "a 20 MB new file is reported as +20 MB",
            row.map { near($0.delta, 20) } ?? false,
            row.map { Format.signedBytes($0.delta) } ?? "no row"
        )

        try? Data(repeating: 9, count: 40 * megabyte).write(to: file)
        settle(2.5)
        row = watcher.rows().first { $0.path == folder.path }
        check(
            "growing it to 40 MB is reported as +40 MB",
            row.map { near($0.delta, 40) } ?? false,
            row.map { Format.signedBytes($0.delta) } ?? "no row"
        )

        try? fm.removeItem(at: file)
        settle(2.5)
        row = watcher.rows(minimumBytes: 0).first { $0.path == folder.path }
        check(
            "deleting it brings the total back to zero",
            row.map { abs($0.delta) < Int64(3 * megabyte) } ?? true,
            row.map { Format.signedBytes($0.delta) } ?? "no row"
        )

        check("the folder was grouped as one row", watcher.rows(minimumBytes: 0).count <= 2)

        // A shrink must read as a shrink. `Format.bytes` clamps negatives to zero,
        // which silently turned every deletion into "Zero KB" in the UI.
        check(
            "a negative delta formats with a sign",
            Format.signedBytes(-500 * Int64(megabyte)).hasPrefix("−"),
            Format.signedBytes(-500 * Int64(megabyte))
        )
        check(
            "a positive delta formats with a plus",
            Format.signedBytes(500 * Int64(megabyte)).hasPrefix("+"),
            Format.signedBytes(500 * Int64(megabyte))
        )
        check("zero formats as zero", Format.signedBytes(0) == "0", Format.signedBytes(0))

        watcher.stop()
        try? fm.removeItem(at: folder)

        print("  " + String(repeating: "─", count: 62))
        print(failures == 0 ? "  Byte deltas are correct\n" : "  \(failures) check(s) FAILED\n")
        exit(failures == 0 ? 0 : 1)
    }

    /// `MacBroom --historytest [keep]` — checks that removals reach the history
    /// log and can be restored from it. With `keep`, the entries are left behind
    /// so the History screen has something real to show.
    private static func historyTest(keep: Bool, restoreOnly: Bool = false) {
        let fm = FileManager.default
        var failures = 0

        func check(_ label: String, _ passed: Bool) {
            if !passed { failures += 1 }
            print("  \(passed ? "✓" : "✗ FAIL")  \(label)")
        }

        /// Bridges the actor into this synchronous entry point.
        func blocking<Value>(_ operation: @escaping @Sendable () async -> Value) -> Value {
            let gate = DispatchSemaphore(value: 0)
            var result: Value?
            Task {
                result = await operation()
                gate.signal()
            }
            gate.wait()
            return result!
        }

        print("\n  Removal history\n  " + String(repeating: "─", count: 62))

        // Must run before anything is created: otherwise this seeds new scratch
        // folders and then "restores" those instead of the pending ones.
        if restoreOnly {
            var restored = 0
            for session in blocking({ await RemovalHistory.shared.all() }) {
                for record in session.records where record.canRestore {
                    if case .success = blocking({ await RemovalHistory.shared.restore(record) }) {
                        restored += 1
                    }
                }
            }
            print("  \(restored) item(s) put back")
            print("  " + String(repeating: "─", count: 62) + "\n")
            exit(0)
        }

        var items: [ScanItem] = []
        for index in 1...3 {
            let folder = SafetyGuard.home.appendingPathComponent(
                "Library/Caches/macbroom-history-test-\(index)",
                isDirectory: true
            )
            try? fm.removeItem(at: folder)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try? Data(repeating: UInt8(index), count: 40_000 * index)
                .write(to: folder.appendingPathComponent("payload.bin"))
            items.append(
                ScanItem(
                    url: folder,
                    displayName: folder.lastPathComponent,
                    size: SizeCalculator.size(of: folder),
                    modified: nil,
                    isSelected: true
                )
            )
        }
        check("3 scratch folders created", items.count == 3)

        let result = Cleaner.trash(items)
        check("all three moved to the Trash", result.removed == 3)
        blocking { await RemovalHistory.shared.add(source: .smartScan, records: result.records) }

        let sessions = blocking { await RemovalHistory.shared.all() }
        let session = sessions.first { $0.records.contains { $0.displayName.hasPrefix("macbroom-history-test") } }
        check("a session was written to the log", session != nil)
        check("it holds all three records", session?.records.count == 3)
        check("every record reports itself restorable", session?.restorableCount == 3)
        check("the freed total adds up", session?.freed == result.freed)

        let reloaded = blocking { await RemovalHistory.shared.all() }
        check("the log survives a reload from disk", !reloaded.isEmpty)

        if keep {
            print("  " + String(repeating: "─", count: 62))
            print("  \(session?.records.count ?? 0) entries left in the history for inspection\n")
            exit(failures == 0 ? 0 : 1)
        }

        var restoreFailures = 0
        for record in session?.records ?? [] {
            if case .failure = blocking({ await RemovalHistory.shared.restore(record) }) {
                restoreFailures += 1
            }
        }
        check("all three restored without error", restoreFailures == 0)
        check(
            "all three are back on disk",
            (1...3).allSatisfy {
                fm.fileExists(
                    atPath: SafetyGuard.home
                        .appendingPathComponent("Library/Caches/macbroom-history-test-\($0)").path
                )
            }
        )

        // Scoped to this run's own session: asserting on the whole log makes the
        // test fail whenever an earlier run left records behind.
        let after = blocking { await RemovalHistory.shared.all() }
        check(
            "restored items are dropped from the log",
            !after.contains { $0.id == session?.id }
        )

        for index in 1...3 {
            try? fm.removeItem(
                at: SafetyGuard.home
                    .appendingPathComponent("Library/Caches/macbroom-history-test-\(index)")
            )
        }

        print("  " + String(repeating: "─", count: 62))
        print(failures == 0 ? "  History and restore both work\n" : "  \(failures) check(s) FAILED\n")
        exit(failures == 0 ? 0 : 1)
    }

    /// `MacBroom --undotest` — a real round trip through Trash and back.
    ///
    /// The History screen promises that anything removed can be put back. That is
    /// only true if `trashItem` really hands over the destination and the move
    /// back really lands in the original place, so it is checked rather than
    /// assumed. Nothing outside a scratch folder in ~/Library/Caches is touched.
    private static func undoTest() {
        let fm = FileManager.default
        let folder = SafetyGuard.home
            .appendingPathComponent("Library/Caches/macbroom-undo-test", isDirectory: true)
        let file = folder.appendingPathComponent("sample.txt")
        var failures = 0

        func check(_ label: String, _ passed: Bool) {
            if !passed { failures += 1 }
            print("  \(passed ? "✓" : "✗ FAIL")  \(label)")
        }

        print("\n  Undo round trip\n  " + String(repeating: "─", count: 62))

        try? fm.removeItem(at: folder)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let payload = Data("macbroom undo test".utf8)
        try? payload.write(to: file)
        check("scratch file created at ~/Library/Caches/macbroom-undo-test", fm.fileExists(atPath: file.path))

        let item = ScanItem(
            url: folder,
            displayName: "macbroom-undo-test",
            size: SizeCalculator.size(of: folder),
            modified: nil,
            isSelected: true
        )
        let result = Cleaner.trash([item])
        check("moved to the Trash", result.removed == 1 && !fm.fileExists(atPath: folder.path))
        check("Trash destination was recorded", result.records.first?.trashedPath != nil)

        guard let record = result.records.first else {
            print("  " + String(repeating: "─", count: 62))
            print("  cannot continue without a record\n")
            exit(1)
        }
        check("still present in the Trash", fm.fileExists(atPath: record.trashedPath ?? ""))
        check("reports itself as restorable", record.canRestore)

        // The actor hop has to be waited on: this is a synchronous entry point.
        let gate = DispatchSemaphore(value: 0)
        var restoreFailure: String?
        Task {
            if case .failure(let error) = await RemovalHistory.shared.restore(record) {
                restoreFailure = error.message(.en)
            }
            gate.signal()
        }
        gate.wait()

        check("restore reported success", restoreFailure == nil)
        check("back at its original path", fm.fileExists(atPath: folder.path))
        check(
            "contents survived the round trip",
            (try? Data(contentsOf: file)) == payload
        )

        try? fm.removeItem(at: folder)
        print("  " + String(repeating: "─", count: 62))
        print(failures == 0 ? "  Undo works end to end\n" : "  \(failures) check(s) FAILED\n")
        exit(failures == 0 ? 0 : 1)
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
