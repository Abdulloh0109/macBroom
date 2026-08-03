import SwiftUI

@main
struct MacBroomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // `MacBroom --scan` prints a report and exits before any window is created.
        CLIRunner.runIfRequested()
    }

    @StateObject private var i18n = I18n()

    var body: some Scene {
        WindowGroup("MacBroom") {
            RootView().environmentObject(i18n)
        }
        // Tall enough that all thirteen screens are in the sidebar without scrolling:
        // at 680 the last two sat below the fold, and macOS hides the scroll bar
        // until the pointer moves, so they looked as if they did not exist.
        .defaultSize(width: 1020, height: 780)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Below this the detail column has nowhere to go, so the window itself refuses
    /// to shrink further rather than letting the content get clipped.
    private let minimumSize = NSSize(width: 760, height: 520)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when the binary is launched straight from SwiftPM's build folder
        // rather than from the .app bundle.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [minimumSize] notification in
            guard let window = notification.object as? NSWindow else { return }
            window.minSize = minimumSize
            Self.applyTestSize(to: window)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// `MacBroom --size 800x560` — used to check the layout survives a small window.
    private static var didApplyTestSize = false

    private static func applyTestSize(to window: NSWindow) {
        guard !didApplyTestSize else { return }
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--size"), index + 1 < args.count else { return }
        let parts = args[index + 1].split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else { return }
        didApplyTestSize = true
        window.setContentSize(NSSize(width: parts[0], height: parts[1]))
    }
}
