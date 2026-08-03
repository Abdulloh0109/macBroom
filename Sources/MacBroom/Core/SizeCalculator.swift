import Foundation

/// Recursive on-disk size measurement. Pure, thread-safe, cancellation aware.
enum SizeCalculator {
    private static let keys: [URLResourceKey] = [
        // volumeIdentifier is deliberately absent: prefetching it for every file
        // costs a statfs each and slowed a home-folder walk by half. It is looked
        // up per directory instead, and directories are a small minority.
        .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
    ]

    /// Allocated size of a file or, recursively, of a directory tree.
    ///
    /// Symlinks are counted as themselves and never followed, and the walk stops at
    /// mount points. That second rule matters: `/Library/Developer/CoreSimulator`
    /// has a simulator runtime mounted inside it, and counting through the mount
    /// reports 19 GB for a folder that actually holds 3 GB — `du` makes exactly
    /// that mistake. A mounted volume's contents belong to that volume, not this one.
    static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            return fileSize(url)
        }

        let rootVolume = (try? url.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier

        var total: Int64 = 0
        guard
            let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [],
                errorHandler: { _, _ in true }
            )
        else { return 0 }

        while let next = enumerator.nextObject() {
            guard let child = next as? URL else { continue }
            if Task.isCancelled { return total }

            if let rootVolume,
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .volumeIdentifierKey]),
                values.isDirectory == true,
                let childVolume = values.volumeIdentifier,
                !childVolume.isEqual(rootVolume)
            {
                enumerator.skipDescendants()
                continue
            }

            total += fileSize(child)
        }
        return total
    }

    private static func fileSize(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if let allocated = values.totalFileAllocatedSize { return Int64(allocated) }
        if let allocated = values.fileAllocatedSize { return Int64(allocated) }
        return Int64(values.fileSize ?? 0)
    }

    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
