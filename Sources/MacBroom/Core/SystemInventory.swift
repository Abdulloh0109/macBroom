import AppKit
import Darwin
import Foundation

// MARK: - Shell helper

enum Shell {
    /// Runs a tool and returns stdout. Used only for read-only system queries
    /// (`mdfind`, `launchctl list`) — never for anything destructive.
    @discardableResult
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 20) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return "" }

        // Read on a background queue so a chatty tool can't deadlock on a full pipe.
        var data = Data()
        let lock = NSLock()
        let reader = DispatchQueue(label: "macbroom.shell.read")
        reader.async {
            let chunk = pipe.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            data = chunk
            lock.unlock()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(20_000)
        }
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        reader.sync {}

        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Applications

enum AppLocation {
    case applications      // /Applications
    case userApplications  // ~/Applications
    case system            // /System/Applications — untouchable
    case elsewhere         // anywhere else: helpers, casks, hidden corners
}

struct AppRecord: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    var size: Int64
    let location: AppLocation
    /// Menu-bar / helper app: runs without a Dock icon (LSUIElement or LSBackgroundOnly).
    let isAgent: Bool
    let isRunning: Bool

    var id: String { url.path }

    /// Shown under "Hidden Apps": no Dock icon, or installed somewhere unusual.
    var isHidden: Bool { isAgent || location == .elsewhere }
    var isRemovable: Bool { location != .system && SafetyGuard.isRemovable(url) }

    static func == (lhs: AppRecord, rhs: AppRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum AppInventory {
    /// Finds app bundles via Spotlight, falling back to a directory sweep when
    /// Spotlight is off. Nested helper apps (Foo.app/Contents/…/Bar.app) are skipped.
    static func all() -> [AppRecord] {
        var paths = spotlightPaths()
        if paths.isEmpty { paths = directoryPaths() }
        paths.formUnion(directoryPaths())

        let runningIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )

        var records: [AppRecord] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard let record = describe(url, runningIDs: runningIDs) else { continue }
            records.append(record)
        }
        return records.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func spotlightPaths() -> Set<String> {
        let output = Shell.run(
            "/usr/bin/mdfind",
            ["kMDItemContentType == 'com.apple.application-bundle'"],
            timeout: 15
        )
        return Set(output.split(separator: "\n").map(String.init).filter(isInteresting))
    }

    private static func directoryPaths() -> Set<String> {
        let fm = FileManager.default
        var found = Set<String>()
        let roots = [
            "/Applications",
            "/Applications/Utilities",
            SafetyGuard.home.path + "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
        ]
        for root in roots {
            let children = (try? fm.contentsOfDirectory(atPath: root)) ?? []
            for child in children where child.hasSuffix(".app") {
                found.insert(root + "/" + child)
            }
        }
        return found
    }

    /// Rejects nested helpers, system frameworks and build/temp noise.
    private static func isInteresting(_ path: String) -> Bool {
        guard path.hasSuffix(".app") else { return false }
        let container = (path as NSString).deletingLastPathComponent
        if container.contains(".app/") || container.hasSuffix(".app") { return false }
        let rejected = [
            "/System/Library/", "/System/Volumes/", "/private/var/folders/", "/Volumes/",
            "/System/Cryptexes/", "/Library/Developer/CoreSimulator/", "/.Trash/",
            "/Library/Developer/Xcode/DerivedData/", "/node_modules/",
        ]
        return !rejected.contains { path.contains($0) }
    }

    private static func describe(_ url: URL, runningIDs: Set<String>) -> AppRecord? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }

        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let info =
            (try? Data(contentsOf: plistURL)).flatMap {
                try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any]
            } ?? [:]

        func flag(_ key: String) -> Bool {
            if let value = info[key] as? Bool { return value }
            if let value = info[key] as? String { return value == "1" || value.lowercased() == "true" }
            if let value = info[key] as? NSNumber { return value.boolValue }
            return false
        }

        let bundleID = info["CFBundleIdentifier"] as? String
        let path = url.path
        let location: AppLocation
        if path.hasPrefix("/System/") {
            location = .system
        } else if path.hasPrefix("/Applications/") {
            location = .applications
        } else if path.hasPrefix(SafetyGuard.home.path + "/Applications/") {
            location = .userApplications
        } else {
            location = .elsewhere
        }

        return AppRecord(
            url: url,
            name: (info["CFBundleName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? url.deletingPathExtension().lastPathComponent,
            bundleID: bundleID,
            version: info["CFBundleShortVersionString"] as? String,
            size: 0,
            location: location,
            isAgent: flag("LSUIElement") || flag("LSBackgroundOnly"),
            isRunning: bundleID.map(runningIDs.contains) ?? false
        )
    }

    /// Support files an app scatters around the home folder.
    static func leftovers(for app: AppRecord) -> [Leftover] {
        let fm = FileManager.default
        let home = SafetyGuard.home
        var needles: Set<String> = []
        if let id = app.bundleID, !id.isEmpty { needles.insert(id.lowercased()) }
        needles.insert(app.name.lowercased())

        let searchDirs = [
            "Library/Application Support",
            "Library/Caches",
            "Library/Preferences",
            "Library/Containers",
            "Library/Group Containers",
            "Library/Saved Application State",
            "Library/HTTPStorages",
            "Library/WebKit",
            "Library/Logs",
            "Library/Cookies",
            "Library/LaunchAgents",
            "Library/Application Scripts",
        ]

        var found: [Leftover] = []
        var seen = Set<String>()

        for dir in searchDirs {
            let root = home.appendingPathComponent(dir)
            let children = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for child in children {
                let name = child.deletingPathExtension().lastPathComponent.lowercased()
                let matches = needles.contains { needle in
                    name == needle || name.hasPrefix(needle + ".") || name.hasSuffix("." + needle)
                        || (needle.count >= 5 && name.contains(needle))
                }
                guard matches, !seen.contains(child.path), SafetyGuard.isRemovable(child) else { continue }
                seen.insert(child.path)
                found.append(Leftover(url: child, size: SizeCalculator.size(of: child)))
            }
        }
        return found.sorted { $0.size > $1.size }
    }
}

struct Leftover: Identifiable, Hashable {
    let url: URL
    let size: Int64
    var isSelected: Bool = true

    var id: String { url.path }
    var kind: String { url.deletingLastPathComponent().lastPathComponent }
}

// MARK: - Running processes

struct ProcessRecord: Identifiable, Hashable {
    let pid: pid_t
    let name: String
    let bundleID: String?
    let bundleURL: URL?
    let memory: Int64
    /// No Dock icon: menu-bar helper or a pure background worker.
    let isBackground: Bool
    let launchDate: Date?
    /// TCP ports this process is listening on — the reason not to quit a dev server.
    let ports: [Int]
    let advice: Advice

    var id: pid_t { pid }
}

enum ProcessInventory {
    static func running() -> [ProcessRecord] {
        let ports = listeningPorts()
        let running = NSWorkspace.shared.runningApplications
        let runningIDs = Set(running.compactMap(\.bundleIdentifier))

        let apps = appRecords(running, ports: ports, runningIDs: runningIDs)

        // A dev server started from a terminal (`npm run web`, `node`, `python -m http.server`)
        // is not a "running application" as far as macOS is concerned, so it would be
        // invisible here — which is exactly the process you most want to find when a
        // port is occupied. Anything holding a listening port gets added by hand.
        let known = Set(apps.map(\.pid))
        let extras = ports.keys
            .filter { !known.contains($0) }
            .compactMap { pid -> ProcessRecord? in
                guard let path = executablePath(pid) else { return nil }
                let isSystemBinary = ["/usr/", "/System/", "/sbin/", "/bin/"].contains {
                    path.hasPrefix($0)
                }
                let open = Array(ports[pid] ?? []).sorted()
                return ProcessRecord(
                    pid: pid,
                    name: (path as NSString).lastPathComponent,
                    bundleID: nil,
                    bundleURL: nil,
                    memory: memoryFootprint(pid),
                    isBackground: true,
                    launchDate: nil,
                    ports: open,
                    advice: isSystemBinary ? .keep : .inUse
                )
            }

        return (apps + extras).sorted { $0.memory > $1.memory }
    }

    private static func appRecords(
        _ running: [NSRunningApplication],
        ports: [pid_t: Set<Int>],
        runningIDs: Set<String>
    ) -> [ProcessRecord] {
        running.compactMap { app -> ProcessRecord? in
            guard app.processIdentifier > 0, !app.isTerminated else { return nil }
            let bundleID = app.bundleIdentifier
            let name =
                app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "—"
            let open = ports[app.processIdentifier].map { Array($0).sorted() } ?? []

            return ProcessRecord(
                pid: app.processIdentifier,
                name: name,
                bundleID: bundleID,
                bundleURL: app.bundleURL,
                memory: memoryFootprint(app.processIdentifier),
                isBackground: app.activationPolicy != .regular,
                launchDate: app.launchDate,
                ports: open,
                advice: advise(
                    bundleID: bundleID,
                    name: name,
                    isBackground: app.activationPolicy != .regular,
                    ports: open,
                    runningIDs: runningIDs
                )
            )
        }
    }

    /// Full path of a process's executable, for processes that have no app bundle.
    static func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    /// Decides what to tell the user about a process. Deliberately cautious:
    /// anything Apple owns is "keep", anything holding a port is "in use".
    private static func advise(
        bundleID: String?,
        name: String,
        isBackground: Bool,
        ports: [Int],
        runningIDs: Set<String>
    ) -> Advice {
        if let id = bundleID, id.hasPrefix("com.apple.") { return .keep }
        if !ports.isEmpty { return .inUse }
        if !isBackground { return .inUse }  // has a Dock icon → the user opened it

        // A helper whose parent app is gone is the classic "I closed the app but it
        // is still running" case — exactly what is worth quitting.
        if let id = bundleID {
            let parent = id.split(separator: ".").dropLast().joined(separator: ".")
            let looksLikeHelper =
                id.lowercased().contains("helper") || name.lowercased().contains("helper")
            if looksLikeHelper, !parent.isEmpty, !runningIDs.contains(parent) { return .leftover }
        }
        if bundleID == nil { return .leftover }  // bare executable: npm, node, scripts

        return .removable
    }

    /// pid → listening TCP ports, via `lsof`. Only covers the current user's
    /// processes, which is all we can act on anyway.
    static func listeningPorts() -> [pid_t: Set<Int>] {
        let output = Shell.run(
            "/usr/sbin/lsof",
            ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pn"],
            timeout: 10
        )

        var result: [pid_t: Set<Int>] = [:]
        var current: pid_t = 0
        for line in output.split(separator: "\n") {
            guard let marker = line.first else { continue }
            let value = line.dropFirst()
            if marker == "p" {
                current = pid_t(value) ?? 0
            } else if marker == "n", current > 0 {
                // "127.0.0.1:8082", "*:3000", "[::1]:5000"
                guard let portText = value.split(separator: ":").last, let port = Int(portText)
                else { continue }
                result[current, default: []].insert(port)
            }
        }
        return result
    }

    /// Physical footprint in bytes — the number Activity Monitor shows as "Memory".
    static func memoryFootprint(_ pid: pid_t) -> Int64 {
        var info = rusage_info_current()
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
            }
        }
        return status == 0 ? Int64(info.ri_phys_footprint) : 0
    }

    /// Asks the process to stop the normal way — `terminate()` for apps, SIGTERM for
    /// plain executables. Never SIGKILL, so the process gets to shut down cleanly.
    static func quit(_ record: ProcessRecord) -> Bool {
        if let app = NSRunningApplication(processIdentifier: record.pid) {
            return app.terminate()
        }
        return kill(record.pid, SIGTERM) == 0
    }
}

// MARK: - Launchd services

enum ServiceScope {
    case user   // ~/Library/LaunchAgents — yours, removable
    case admin  // /Library/Launch{Agents,Daemons} — needs an administrator
    case system // /System/Library/… — protected by macOS
}

struct ServiceRecord: Identifiable, Hashable {
    let url: URL
    let label: String
    let program: String
    let scope: ServiceScope
    let runAtLoad: Bool
    let isLoaded: Bool
    let isApple: Bool

    var id: String { url.path }
    var isRemovable: Bool { scope == .user && SafetyGuard.isRemovable(url) }
}

enum ServiceInventory {
    static func all() -> [ServiceRecord] {
        let loaded = loadedLabels()
        var records: [ServiceRecord] = []

        let sources: [(String, ServiceScope)] = [
            (SafetyGuard.home.path + "/Library/LaunchAgents", .user),
            ("/Library/LaunchAgents", .admin),
            ("/Library/LaunchDaemons", .admin),
            ("/System/Library/LaunchAgents", .system),
            ("/System/Library/LaunchDaemons", .system),
        ]

        for (path, scope) in sources {
            let children = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
            for child in children where child.hasSuffix(".plist") {
                let url = URL(fileURLWithPath: path + "/" + child)
                guard let record = describe(url, scope: scope, loaded: loaded) else { continue }
                records.append(record)
            }
        }

        return records.sorted { lhs, rhs in
            if lhs.isLoaded != rhs.isLoaded { return lhs.isLoaded }
            return lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
        }
    }

    private static func describe(_ url: URL, scope: ServiceScope, loaded: Set<String>) -> ServiceRecord? {
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        let label = (plist["Label"] as? String) ?? url.deletingPathExtension().lastPathComponent
        var program = plist["Program"] as? String ?? ""
        if program.isEmpty, let arguments = plist["ProgramArguments"] as? [String] {
            program = arguments.first ?? ""
        }

        return ServiceRecord(
            url: url,
            label: label,
            program: program,
            scope: scope,
            runAtLoad: (plist["RunAtLoad"] as? Bool) ?? false,
            isLoaded: loaded.contains(label),
            isApple: label.hasPrefix("com.apple.")
        )
    }

    private static func loadedLabels() -> Set<String> {
        let output = Shell.run("/bin/launchctl", ["list"], timeout: 10)
        var labels = Set<String>()
        for line in output.split(separator: "\n").dropFirst() {
            if let label = line.split(separator: "\t").last {
                labels.insert(String(label))
            }
        }
        return labels
    }

    /// Stops the job, then trashes its plist. Only ever touches ~/Library/LaunchAgents,
    /// and `SafetyGuard` is the final word on whether the file may move.
    static func disable(_ service: ServiceRecord) -> Cleaner.Result {
        var result = Cleaner.Result()
        guard service.isRemovable else {
            result.failures.append(
                Cleaner.Failure(path: service.url.path, reason: S.readOnlyService(Localized.current))
            )
            return result
        }

        let uid = getuid()
        Shell.run("/bin/launchctl", ["bootout", "gui/\(uid)/\(service.label)"], timeout: 8)

        let size = SizeCalculator.size(of: service.url)
        do {
            try SafetyGuard.assertRemovable(service.url)
            try FileManager.default.trashItem(at: service.url, resultingItemURL: nil)
            result.freed += size
            result.removed += 1
        } catch {
            result.failures.append(
                Cleaner.Failure(path: service.url.path, reason: error.localizedDescription)
            )
        }
        return result
    }
}
