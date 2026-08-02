import Foundation

/// The single choke point that decides whether MacBroom is allowed to remove a path.
///
/// Everything that deletes goes through `assertRemovable(_:)`. The rules are deliberately
/// paranoid: an allow-list of roots, a deny-list of well known folders that must survive,
/// and a depth requirement so we can never nuke a top level directory by accident.
enum SafetyGuard {
    enum Violation: LocalizedError {
        case outsideAllowedRoots(URL)
        case protectedDirectory(URL)
        case tooShallow(URL)
        case symlinkedOutside(URL)

        var errorDescription: String? {
            switch self {
            case .outsideAllowedRoots(let url):
                return "Refused: \(url.path) is outside the folders MacBroom may touch."
            case .protectedDirectory(let url):
                return "Refused: \(url.path) is a protected folder."
            case .tooShallow(let url):
                return "Refused: \(url.path) is a top-level folder."
            case .symlinkedOutside(let url):
                return "Refused: \(url.path) resolves outside the allowed folders."
            }
        }
    }

    static let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    /// Roots MacBroom is ever allowed to remove something from.
    static var allowedRoots: [URL] {
        [home, URL(fileURLWithPath: "/Applications", isDirectory: true)]
    }

    /// Folders that must always survive, even though they sit inside an allowed root.
    static var protectedPaths: Set<String> {
        var paths: Set<String> = [
            "/", "/Applications", "/Library", "/System", "/Users", "/private", "/usr", "/bin", "/etc", "/opt", "/var",
        ]
        let h = home.path
        for sub in [
            "", "/Library", "/Documents", "/Desktop", "/Downloads", "/Pictures", "/Movies", "/Music", "/Public",
            "/Applications", "/.Trash", "/.ssh", "/.gnupg", "/.config", "/.aws", "/.kube",
            "/Library/Caches", "/Library/Logs", "/Library/Preferences", "/Library/Containers",
            "/Library/Application Support", "/Library/Group Containers", "/Library/Mobile Documents",
            "/Library/Keychains", "/Library/Developer", "/Library/Developer/Xcode",
            "/Library/Developer/CoreSimulator", "/Library/Developer/CoreSimulator/Devices",
        ] {
            paths.insert(h + sub)
        }
        return paths
    }

    /// Throws unless `url` is safe to move to the Trash.
    static func assertRemovable(_ url: URL) throws {
        let std = url.standardizedFileURL
        let path = std.path

        if protectedPaths.contains(path) {
            throw Violation.protectedDirectory(std)
        }

        guard let root = allowedRoots.first(where: { isDescendant(path, of: $0.path) }) else {
            throw Violation.outsideAllowedRoots(std)
        }

        // Never remove a direct child of "/Applications" unless it is an app bundle,
        // and never remove anything shallower than <root>/<something>.
        let relative = String(path.dropFirst(root.path.count)).split(separator: "/").map(String.init)
        if relative.isEmpty { throw Violation.tooShallow(std) }
        if root.path == "/Applications" && !(relative.count == 1 && path.hasSuffix(".app")) {
            throw Violation.protectedDirectory(std)
        }

        // A symlink whose target escapes the allowed roots would let us delete anything.
        let resolved = std.resolvingSymlinksInPath().path
        if resolved != path, !allowedRoots.contains(where: { isDescendant(resolved, of: $0.path) }) {
            throw Violation.symlinkedOutside(std)
        }
    }

    static func isRemovable(_ url: URL) -> Bool {
        (try? assertRemovable(url)) != nil
    }

    private static func isDescendant(_ path: String, of root: String) -> Bool {
        let root = root.hasSuffix("/") ? String(root.dropLast()) : root
        return path.hasPrefix(root + "/")
    }
}
