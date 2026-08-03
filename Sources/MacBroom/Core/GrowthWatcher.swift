import CoreServices
import Foundation

struct GrowthRow: Identifiable, Hashable {
    let path: String
    let delta: Int64
    let events: Int

    var id: String { path }
    var name: String {
        path.replacingOccurrences(of: SafetyGuard.home.path, with: "~")
    }
}

/// Answers "the disk lost 10 GB in the last hour — what did it?"
///
/// Re-measuring folders on a timer would be the obvious way and is far too
/// expensive: `~/Progects/App` alone is 100k files. Instead this listens to
/// FSEvents and accumulates byte deltas from the events themselves, which costs
/// one `stat` per changed file and gives real numbers rather than estimates.
///
/// A file seen for the first time via a *modify* event contributes nothing: its
/// earlier size is unknown, and guessing would overstate growth badly. Created
/// files count in full, removed files count against, and later modifications of
/// an already-seen file count the difference. The result converges on the truth
/// and never invents it.
final class GrowthWatcher {
    private let lock = NSLock()
    private var knownSizes: [String: Int64] = [:]
    private var growth: [String: Int64] = [:]
    private var eventCounts: [String: Int] = [:]

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "macbroom.growth", qos: .utility)

    /// How many path components below the watch root a row is grouped at.
    /// Depth 3 from home lands on things like `~/Library/Caches/Google`.
    private let bucketDepth: Int
    private var rootComponents = 0
    private(set) var root: URL?
    private(set) var startedAt: Date?

    init(bucketDepth: Int = 3) {
        self.bucketDepth = bucketDepth
    }

    // MARK: - Lifecycle

    func start(root: URL) {
        stop()

        let standardized = root.standardizedFileURL
        self.root = standardized
        startedAt = Date()

        lock.lock()
        // Written under the lock because the FSEvents callback reads it from
        // another thread while bucketing paths.
        rootComponents = standardized.path.split(separator: "/").count
        knownSizes = [:]
        growth = [:]
        eventCounts = [:]
        lock.unlock()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }
            let watcher = Unmanaged<GrowthWatcher>.fromOpaque(info).takeUnretainedValue()
            let pathList = unsafeBitCast(paths, to: NSArray.self)
            for index in 0..<count {
                guard let path = pathList[index] as? String else { continue }
                watcher.handle(path: path, flags: flags[index])
            }
        }

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [standardized.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.7,
            FSEventStreamCreateFlags(
                // UseCFTypes is not optional here: without it `eventPaths` arrives as
                // a C `char **`, and reading it as a CFArray segfaults.
                kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer
                    | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot
            )
        )

        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        root = nil
        startedAt = nil
    }

    // MARK: - Accounting

    private func handle(path: String, flags: FSEventStreamEventFlags) {
        // Our own scratch and the Trash would otherwise dominate the list.
        if path.contains("/.Trash/") || path.contains("/Application Support/MacBroom/") { return }

        let created = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
        let removed = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0
        let isDirectory = flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir) != 0
        if isDirectory { return }  // directory entries carry no bytes of their own

        let current = fileSize(path)

        lock.lock()
        defer { lock.unlock() }

        let bucket = self.bucket(for: path, rootComponents: rootComponents)
        eventCounts[bucket, default: 0] += 1

        // A build touching millions of files must not turn this into a memory leak.
        // Dropping the table costs accuracy on files already seen, not correctness:
        // they are simply treated as newly observed again.
        if knownSizes.count > 250_000 { knownSizes.removeAll(keepingCapacity: true) }

        let known = knownSizes[path]

        if removed || current == nil {
            if let known { growth[bucket, default: 0] -= known }
            knownSizes[path] = nil
            return
        }

        guard let current else { return }

        if let known {
            growth[bucket, default: 0] += current - known
        } else if created {
            growth[bucket, default: 0] += current
        }
        // First sighting of a pre-existing file: record the size, claim no growth.
        knownSizes[path] = current
    }

    private func fileSize(_ path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        guard
            let values = try? url.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey,
            ]),
            values.isRegularFile == true
        else { return nil }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    /// Groups a changed file under an ancestor a few levels below the watch root,
    /// so the list reads as a handful of folders rather than thousands of files.
    /// Caller holds the lock; `rootComponents` is passed in rather than read here.
    private func bucket(for path: String, rootComponents: Int) -> String {
        let parts = path.split(separator: "/")
        let keep = min(parts.count - 1, rootComponents + bucketDepth)
        guard keep > 0 else { return path }
        return "/" + parts.prefix(keep).joined(separator: "/")
    }

    // MARK: - Reading

    func rows(minimumBytes: Int64 = 64 * 1024) -> [GrowthRow] {
        lock.lock()
        let snapshot = growth
        let counts = eventCounts
        lock.unlock()

        return snapshot
            .filter { abs($0.value) >= minimumBytes }
            .map { GrowthRow(path: $0.key, delta: $0.value, events: counts[$0.key] ?? 0) }
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    var totalDelta: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return growth.values.reduce(0, +)
    }

    var observedFiles: Int {
        lock.lock()
        defer { lock.unlock() }
        return knownSizes.count
    }
}
