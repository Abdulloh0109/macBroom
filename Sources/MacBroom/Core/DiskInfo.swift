import Foundation

struct DiskInfo {
    var total: Int64 = 0
    /// Bytes actually free right now — what `df` reports.
    var available: Int64 = 0
    /// Extra bytes macOS believes it *could* free by evicting caches and offloading
    /// files to iCloud. Real, but not yours until the system decides to reclaim it,
    /// so it is never counted as free space.
    var purgeable: Int64 = 0

    var used: Int64 { max(0, total - available) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    static func current() -> DiskInfo {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return DiskInfo() }

        // `volumeAvailableCapacity` lags inside a long-running process: after writing
        // 470 MB it still reported the old figure while `df` had already moved. The
        // live watcher's whole headline is "free space just changed by X", so the
        // number comes from statfs, which is a syscall and cannot go stale.
        var fresh = statfs()
        let statfsOK = statfs(NSHomeDirectory(), &fresh) == 0
        let total =
            statfsOK
            ? Int64(fresh.f_blocks) * Int64(fresh.f_bsize)
            : Int64(values.volumeTotalCapacity ?? 0)
        let available =
            statfsOK
            ? Int64(fresh.f_bavail) * Int64(fresh.f_bsize)
            : Int64(values.volumeAvailableCapacity ?? 0)
        // `…ForImportantUsage` bundles purgeable space into its answer. Reporting it
        // as free overstates the disk by tens of gigabytes, which is exactly the
        // number a cleaner must not get wrong.
        let optimistic = values.volumeAvailableCapacityForImportantUsage ?? available

        return DiskInfo(
            total: total,
            available: available,
            purgeable: max(0, optimistic - available)
        )
    }
}
