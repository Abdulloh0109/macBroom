import Foundation

enum ArtifactKind: String, CaseIterable {
    case nodeModules
    case buildOutput
    case pods
    case gradle
    case rustTarget
    case python
    case vendor
    case derivedData

    var label: T {
        switch self {
        case .nodeModules: return S.kindNodeModules
        case .buildOutput: return S.kindBuildOutput
        case .pods: return S.kindPods
        case .gradle: return S.kindGradle
        case .rustTarget: return S.kindTarget
        case .python: return S.kindPython
        case .vendor: return S.kindVendor
        case .derivedData: return S.kindDerivedData
        }
    }

    var symbol: String {
        switch self {
        case .nodeModules: return "shippingbox"
        case .buildOutput: return "hammer"
        case .pods: return "cube.box"
        case .gradle: return "a.square"
        case .rustTarget: return "gearshape.2"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .vendor: return "tray.full"
        case .derivedData: return "wrench.and.screwdriver"
        }
    }

    /// How it comes back if you remove it — shown so the user knows the cost.
    var restoreCommand: String {
        switch self {
        case .nodeModules: return "npm install"
        case .buildOutput: return "npm run build"
        case .pods: return "pod install"
        case .gradle: return "./gradlew build"
        case .rustTarget: return "cargo build"
        case .python: return "pip install -r requirements.txt"
        case .vendor: return "composer install / go mod download"
        case .derivedData: return "Xcode build"
        }
    }
}

struct ProjectArtifact: Identifiable, Hashable {
    let url: URL
    let projectURL: URL
    let projectName: String
    let kind: ArtifactKind
    var size: Int64
    let modified: Date?
    var isSelected: Bool = false

    var id: String { url.path }

    /// Untouched for a season: almost certainly a project you are not working on.
    var advice: Advice {
        guard let modified else { return .removable }
        return Date().timeIntervalSince(modified) > 90 * 86_400 ? .leftover : .removable
    }
}

/// Finds dependency and build directories inside real projects.
///
/// The rule that keeps this safe: a folder only counts as a build artifact when its
/// parent looks like a project. A stray `~/Documents/build` with no `package.json`
/// next to it is somebody's actual work, not something to offer up for deletion.
enum ProjectScanner {
    private struct Rule {
        let name: String
        let kind: ArtifactKind
        /// One of these must sit next to the folder. Empty means "always safe".
        let markers: [String]
    }

    private static let rules: [Rule] = [
        Rule(name: "node_modules", kind: .nodeModules, markers: ["package.json"]),
        Rule(name: ".next", kind: .buildOutput, markers: ["package.json"]),
        Rule(name: ".nuxt", kind: .buildOutput, markers: ["package.json"]),
        Rule(name: ".turbo", kind: .buildOutput, markers: ["package.json"]),
        Rule(name: ".parcel-cache", kind: .buildOutput, markers: ["package.json"]),
        Rule(name: ".svelte-kit", kind: .buildOutput, markers: ["package.json"]),
        Rule(name: "dist", kind: .buildOutput, markers: ["package.json"]),
        Rule(name: "out", kind: .buildOutput, markers: ["package.json"]),
        Rule(name: "coverage", kind: .buildOutput, markers: ["package.json"]),
        Rule(
            name: "build",
            kind: .buildOutput,
            markers: ["package.json", "build.gradle", "build.gradle.kts", "CMakeLists.txt", "pom.xml"]
        ),
        Rule(name: "Pods", kind: .pods, markers: ["Podfile"]),
        Rule(
            name: ".gradle",
            kind: .gradle,
            markers: ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"]
        ),
        Rule(name: "target", kind: .rustTarget, markers: ["Cargo.toml", "pom.xml"]),
        Rule(name: "__pycache__", kind: .python, markers: []),
        Rule(
            name: ".venv",
            kind: .python,
            markers: ["requirements.txt", "pyproject.toml", "setup.py", "Pipfile"]
        ),
        Rule(
            name: "venv",
            kind: .python,
            markers: ["requirements.txt", "pyproject.toml", "setup.py", "Pipfile"]
        ),
        Rule(name: "vendor", kind: .vendor, markers: ["composer.json", "go.mod"]),
        Rule(name: "DerivedData", kind: .derivedData, markers: []),
    ]

    private static let ruleByName: [String: Rule] = Dictionary(
        uniqueKeysWithValues: rules.map { ($0.name, $0) }
    )

    /// Directories never worth descending into while looking for projects.
    private static let skip: Set<String> = [
        "Library", "Applications", ".Trash", ".git", "Photos Library.photoslibrary",
        "Music", "Movies", "Pictures",
    ]

    /// Walks `root` (breadth-first, depth-limited) and returns artifacts, unsized.
    static func discover(root: URL, maxDepth: Int = 6) -> [ProjectArtifact] {
        let fm = FileManager.default
        var found: [ProjectArtifact] = []
        var queue: [(URL, Int)] = [(root.standardizedFileURL, 0)]

        while !queue.isEmpty {
            if Task.isCancelled { return found }
            let (directory, depth) = queue.removeFirst()
            guard depth <= maxDepth else { continue }

            let children =
                (try? fm.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                    options: []
                )) ?? []

            // The project marker check needs to know what else lives here.
            let siblingNames = Set(children.map(\.lastPathComponent))

            for child in children {
                guard
                    let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                    values.isDirectory == true,
                    values.isSymbolicLink != true
                else { continue }

                let name = child.lastPathComponent

                if let rule = ruleByName[name],
                    rule.markers.isEmpty || rule.markers.contains(where: siblingNames.contains),
                    SafetyGuard.isRemovable(child)
                {
                    found.append(
                        ProjectArtifact(
                            url: child.standardizedFileURL,
                            projectURL: directory,
                            projectName: directory.lastPathComponent,
                            kind: rule.kind,
                            size: 0,
                            modified: SizeCalculator.modificationDate(of: child)
                        )
                    )
                    continue  // never descend into an artifact
                }

                if skip.contains(name) { continue }
                // Hidden folders are skipped unless a rule names them explicitly.
                if name.hasPrefix("."), ruleByName[name] == nil { continue }
                queue.append((child, depth + 1))
            }
        }

        return found
    }
}
