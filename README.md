# MacBroom

A free, open, native macOS cleaner — a CleanMyMac-style tool without the licence fee.
Swift + SwiftUI, no dependencies, no network code, no telemetry. 2.7 MB.

**Interface in Uzbek and English**, switchable at runtime from the sidebar.
Full walkthrough with screenshots: **[document.md](document.md)** (o'zbekcha).

![Smart Scan](docs/smart-scan.png)

## What it does

| Screen                    | What it shows                                                                                                              |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Smart Scan**            | Caches, logs, developer build junk, Trash, stale installers — grouped, sized, removable in one pass                        |
| **Disk Map** | Squarified treemap of any folder, built in one pass — click a tile to drill in |
| **Large & Old Files**     | Any folder walked for files above a size threshold, largest first, hidden folders included                                 |
| **Developer Projects** | `node_modules`, build output, `Pods`, `.gradle`, `target` grouped per project, with the command that restores each |
| **Installed Apps**        | Every app on the machine with its size, plus a real uninstaller that also removes the support files it left in `~/Library` |
| **Hidden Apps**           | Menu-bar helpers (`LSUIElement`) and apps installed outside the normal places — the ones you never notice                  |
| **Running in Background** | Live processes sorted by memory footprint, each labelled *Can remove / Left over / In use / Keep*, with listening TCP ports shown |
| **Startup Services**      | launchd agents and daemons, whether they are active, and which ones you may turn off                                       |

### Smart Scan locations

| Category             | Covers                                                                              |
| -------------------- | ----------------------------------------------------------------------------------- |
| User Caches          | `~/Library/Caches`                                                                  |
| Developer Caches     | npm, yarn, pnpm, Bun, Deno, CocoaPods, Homebrew, pip, Gradle, Cargo, Go, `~/.cache` |
| Xcode Junk           | DerivedData, archives, iOS/watchOS/tvOS device support, simulator caches            |
| Browser Caches       | Chrome, Safari, Firefox, Brave, Edge, Arc                                           |
| Logs & Crash Reports | `~/Library/Logs`, CrashReporter                                                     |
| Mail Downloads       | Attachments Mail.app copied out of messages                                         |
| Trash                | What is already in `~/.Trash`                                                       |
| Stale Installers     | `.dmg`/`.pkg`/`.iso`/`.zip` in `~/Downloads` older than 60 days                     |
| iOS Device Backups   | Local iPhone/iPad backups                                                           |

## Safety

This is the part that matters in a tool that deletes things.

1. **Nothing is ever deleted permanently.** Every removal is `FileManager.trashItem` — it goes
   to the Trash and you can put it back. Emptying the Trash stays a separate, manual act.
2. **Every path passes through [`SafetyGuard`](Sources/MacBroom/Core/SafetyGuard.swift)**: an
   allow-list of roots, a deny-list of folders that must survive, a minimum depth so a top-level
   directory can never be the target, and a symlink-escape check.
3. **You confirm before anything moves.** Items are listed with sizes; categories marked
   `Check` (backups, downloads) are never pre-selected.
4. **Overlaps can't double-count.** `~/Library/Caches/Google/Chrome` and `~/Library/Caches/Google`
   would otherwise be counted twice and collide on delete; the scanner splits the outer path into
   its children instead.
5. **Services and processes get the gentle treatment.** Quitting asks the process to stop the
   normal way (`terminate` for apps, SIGTERM for bare executables — never SIGKILL); disabling a
   service runs `launchctl bootout` and trashes the plist, and only ever for agents in
   `~/Library/LaunchAgents` — anything system-owned is read-only.
6. **Free space is the real number.** macOS's `…ForImportantUsage` capacity folds in
   purgeable bytes and reported 122 GB free on a disk `df` said had 38 GB. The gauge shows
   what is actually free and lists purgeable space separately.
7. **The app says what it thinks you should do.** Every process and cache item carries an explicit
   verdict rather than leaving you to guess: Apple-owned processes are *Keep* with the Quit button
   disabled, anything holding a listening TCP port is *In use* (its port numbers are shown), and a
   helper whose parent app already exited is *Left over* — the one actually worth closing. A
   terminal-launched dev server is not a "running application" to macOS, so processes holding
   ports are added to the list explicitly instead of being invisible.

Verify the guard yourself — 31 assertions:

```bash
./build/MacBroom.app/Contents/MacOS/MacBroom --selftest
```

## Build

Requires Xcode command line tools (Swift 5.9+), macOS 13+.

```bash
./Scripts/make_icon.swift .      # optional — generates Resources/AppIcon.icns
./Scripts/build_app.sh release   # → build/MacBroom.app
open build/MacBroom.app
```

Drag `build/MacBroom.app` into `/Applications` to keep it. The bundle is ad-hoc signed, so the
first launch may need **right-click → Open**.

## Terminal mode

Read-only. Reports what the GUI would offer; removes nothing.

```bash
MacBroom --scan          # report in the saved language
MacBroom --scan --en     # force English
MacBroom --scan --uz     # force Uzbek
MacBroom --scan --json   # machine readable
MacBroom --map ~         # disk map as text, sorted by size
MacBroom --selftest      # SafetyGuard assertions
```

## Notes

- Quit an app before clearing its cache. Nothing breaks if you don't — the cache is rewritten —
  but a running app may hold stale state until relaunch.
- `~/Downloads`, `~/Desktop` and `~/Documents` trigger a macOS permission prompt the first time.
  Deny it and those folders are simply skipped.
- Developer caches are the big win on a dev machine and all repopulate on next use. `npm cache`
  and `Homebrew downloads` alone were 9 GB on the machine this was built on.

## Layout

```
Sources/MacBroom/
  App/         entry point
  Core/        SafetyGuard, ScanCatalog, SizeCalculator, Cleaner, DiskMap, ProjectScanner,
               SystemInventory (apps/processes/services), Localization, CLIRunner
  Features/    SmartScanModel, LargeFilesModel, DiskMapModel, ProjectsModel,
               AppsModel, ProcessesModel, ServicesModel
  Views/       RootView, SmartScanView, DiskMapView, LargeFilesView, ProjectsView,
               AppsView, ProcessesView, ServicesView, Components
Scripts/       build_app.sh, make_icon.swift
```

Adding a cleanup location is one line in `ScanCatalog.rules`. Adding a translated string is one
line in `Localization.swift` — both languages sit side by side, so a missing translation is a
compile error rather than a silent fallback.

## Licence

MIT — do whatever you want with it.
