import Foundation

/// What to do about a chunk of space that lives outside the home folder.
enum SystemDataAction {
    /// MacBroom will not touch it and neither should you — shown to explain the number.
    case explainOnly
    /// Needs an administrator or another tool; the exact command is offered instead
    /// of a button, because escalating privileges to delete system files is not a
    /// thing this app is willing to do quietly.
    case command(String)
}

struct SystemDataEntry: Identifiable {
    let id: String
    let path: String
    let displayName: String
    let explanation: T
    let action: SystemDataAction
    var size: Int64 = 0
    var extraDetail: String?

    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

/// Explains the space that every other cleaner leaves as a mystery: the gap
/// between "free" and "purgeable", and the gigabytes living outside ~/ that a
/// home-folder scan can never see.
enum SystemDataScanner {
    static func entries() -> [SystemDataEntry] {
        var list: [SystemDataEntry] = [
            SystemDataEntry(
                id: "simruntimes",
                path: "/Library/Developer/CoreSimulator",
                displayName: "iOS Simulator runtimes",
                explanation: S.sdSimulators,
                action: .command("xcrun simctl runtime list"),
                extraDetail: simulatorRuntimes()
            ),
            SystemDataEntry(
                id: "clt",
                path: "/Library/Developer/CommandLineTools",
                displayName: "Command Line Tools",
                explanation: S.sdCommandLineTools,
                action: .command("sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install")
            ),
            SystemDataEntry(
                id: "vm",
                path: "/private/var/vm",
                displayName: "Sleep image & swap",
                explanation: S.sdSleepImage,
                action: .explainOnly
            ),
            SystemDataEntry(
                id: "brew",
                path: "/opt/homebrew",
                displayName: "Homebrew",
                explanation: S.sdHomebrew,
                action: .command("brew cleanup --prune=all")
            ),
            SystemDataEntry(
                id: "libcaches",
                path: "/Library/Caches",
                displayName: "/Library/Caches",
                explanation: S.sdSystemCaches,
                action: .command("sudo rm -rf /Library/Caches/*")
            ),
            SystemDataEntry(
                id: "liblogs",
                path: "/Library/Logs",
                displayName: "/Library/Logs",
                explanation: S.sdSystemLogs,
                action: .command("sudo rm -rf /Library/Logs/*")
            ),
            SystemDataEntry(
                id: "apps",
                path: "/Applications",
                displayName: "/Applications",
                explanation: S.sdApplications,
                action: .explainOnly
            ),
        ]

        // Time Machine keeps hourly snapshots on the startup disk. They are the
        // usual answer to "why is System Data so big", so they get their own row
        // even when there are none — the zero is itself informative.
        let snapshots = localSnapshots()
        list.append(
            SystemDataEntry(
                id: "snapshots",
                path: "/",
                displayName: "Time Machine local snapshots",
                explanation: S.sdSnapshots,
                action: .command("sudo tmutil thinlocalsnapshots / 20000000000 4"),
                extraDetail: snapshots.isEmpty
                    ? nil
                    : snapshots.prefix(3).joined(separator: "\n") + (snapshots.count > 3 ? "\n…" : "")
            )
        )

        return list
    }

    /// Snapshot names, newest last. Reads without admin rights.
    static func localSnapshots() -> [String] {
        Shell.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"], timeout: 10)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("com.apple.TimeMachine") }
    }

    /// The simulator runtime list, which is where the CoreSimulator gigabytes go.
    static func simulatorRuntimes() -> String? {
        let output = Shell.run("/usr/bin/xcrun", ["simctl", "runtime", "list"], timeout: 20)
        let lines = output.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { ($0.contains(" - ") && $0.contains("(")) || $0.hasPrefix("Total Disk Images") }
        // simctl's own total is authoritative for the runtime images, which live
        // outside this folder on a mounted volume.
        return lines.isEmpty ? nil : lines.prefix(5).joined(separator: "\n")
    }

    /// Snapshot count is cheap and worth showing even before sizes are measured.
    static func snapshotCount() -> Int { localSnapshots().count }
}
