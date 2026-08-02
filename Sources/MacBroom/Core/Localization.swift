import Foundation

enum Language: String, CaseIterable, Identifiable {
    case uz
    case en

    var id: String { rawValue }
    var short: String { self == .uz ? "UZ" : "EN" }
    var title: String { self == .uz ? "O'zbekcha" : "English" }
}

/// A string in both languages. Keeping them side by side means a missing
/// translation is a compile error, not a key that silently falls back.
struct T {
    let en: String
    let uz: String

    init(_ en: String, _ uz: String) {
        self.en = en
        self.uz = uz
    }

    func callAsFunction(_ language: Language) -> String {
        language == .uz ? uz : en
    }
}

@MainActor
final class I18n: ObservableObject {
    private static let key = "MacBroomLanguage"

    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
            Localized.current = language
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.key)
        language = stored.flatMap(Language.init(rawValue:)) ?? .uz
        Localized.current = language
    }

    func t(_ text: T) -> String { text(language) }
}

/// Read-only mirror of the active language for non-SwiftUI code (formatters, CLI).
enum Localized {
    nonisolated(unsafe) static var current: Language = .uz
}

// MARK: - Strings

enum S {
    // Shell
    static let appTagline = T("Free your disk", "Diskingizni bo'shating")
    static let refresh = T("Refresh", "Yangilash")
    static let free = T("free", "bo'sh")
    static let cancel = T("Cancel", "Bekor qilish")
    static let stop = T("Stop", "To'xtatish")
    static let none = T("None", "Hech biri")
    static let revealInFinder = T("Show in Finder", "Finder'da ochish")
    static let loading = T("Loading…", "Yuklanmoqda…")
    static let language = T("Language", "Til")

    static func diskUsed(_ used: String, _ total: String) -> T {
        T("\(used) of \(total) used", "\(total) dan \(used) band")
    }

    static func purgeableHint(_ size: String) -> T {
        T(
            "+\(size) macOS can reclaim on demand",
            "+\(size) ni macOS kerak bo'lganda bo'shatadi"
        )
    }

    static func items(_ count: Int) -> T {
        T("\(count) items", "\(count) ta")
    }

    static func moreItems(_ count: Int) -> T {
        T("+ \(count) more", "yana \(count) ta")
    }

    // Features
    static let smartScan = T("Smart Scan", "Aqlli tekshiruv")
    static let largeFiles = T("Large & Old Files", "Katta va eski fayllar")
    static let apps = T("Installed Apps", "O'rnatilgan ilovalar")
    static let hiddenApps = T("Hidden Apps", "Yashirin ilovalar")
    static let processes = T("Running in Background", "Fonda ishlayotganlar")
    static let services = T("Startup Services", "Avtomatik xizmatlar")
    static let projects = T("Developer Projects", "Loyihalar")
    static let diskMap = T("Disk Map", "Disk xaritasi")

    // Smart Scan
    static let scan = T("Scan", "Tekshirish")
    static let rescan = T("Rescan", "Qayta tekshirish")
    static let smartScanIntro = T(
        "Find caches, logs and build junk you can safely reclaim.",
        "Kesh, log va dasturchi chiqindilarini topib, disk joyini bo'shatadi."
    )
    static let searchingJunk = T("Looking for junk…", "Keraksiz fayllar qidirilmoqda…")
    static let scanComplete = T("Scan complete", "Tekshiruv tugadi")
    static let nothingToClean = T("Nothing to clean", "Tozalaydigan narsa yo'q")
    static let readyTitle = T("Ready when you are", "Boshlashga tayyor")
    static let readyBody = T(
        "MacBroom looks through caches, logs, developer build artifacts and the Trash. "
            + "Everything it removes goes to the Trash first, so you can always put it back.",
        "MacBroom kesh, log, dasturchi fayllari va Savatni ko'rib chiqadi. "
            + "O'chirilgan hamma narsa avval Savatga tushadi — istalgan payt qaytarib olasiz."
    )
    static let allCleanTitle = T("All clean", "Hammasi toza")
    static let allCleanBody = T(
        "Nothing worth removing was found in the scanned locations.",
        "Tekshirilgan joylarda o'chirishga arziydigan narsa topilmadi."
    )
    static let safeOnly = T("Safe only", "Faqat xavfsizlari")
    static let moveToTrash = T("Move to Trash", "Savatga tashlash")
    static let cleaning = T("Cleaning…", "Tozalanmoqda…")
    static let trashNote = T(
        "Nothing is deleted permanently — you can restore items from the Trash.",
        "Hech narsa butunlay o'chmaydi — Savatdan qaytarib olsangiz bo'ladi."
    )

    static func measuring(_ done: Int, _ total: Int) -> T {
        T("Measuring… \(done)/\(total)", "O'lchanmoqda… \(done)/\(total)")
    }

    static func reclaimable(_ size: String, _ count: Int) -> T {
        T(
            "\(size) reclaimable across \(count) categories.",
            "\(count) ta bo'limda \(size) bo'shatish mumkin."
        )
    }

    static func freed(_ size: String) -> T {
        T("Freed \(size)", "\(size) bo'shatildi")
    }

    static func freedNothingLeft(_ size: String) -> T {
        T(
            "Freed \(size). Nothing left to clean.",
            "\(size) bo'shatildi. Boshqa tozalaydigan narsa qolmadi."
        )
    }

    static func selectedItems(_ count: Int) -> T {
        T("\(count) items selected", "\(count) ta element tanlandi")
    }

    static func confirmTrash(_ count: Int, _ size: String) -> T {
        T(
            "Move \(count) items (\(size)) to the Trash?",
            "\(count) ta element (\(size)) Savatga tashlansinmi?"
        )
    }

    static func movingToTrash(_ count: Int) -> T {
        T("Moving \(count) items to the Trash…", "\(count) ta element Savatga ko'chirilmoqda…")
    }

    static func couldNotRemove(_ count: Int) -> T {
        T("\(count) item(s) could not be removed", "\(count) ta elementni o'chirib bo'lmadi")
    }

    // Risk
    static let riskSafe = T("Safe", "Xavfsiz")
    static let riskReview = T("Check", "Tekshiring")

    // Advice
    static let adviceRemovable = T("Can remove", "O'chirish mumkin")
    static let adviceRemovableWhy = T(
        "Nothing is using it — removing it is safe.",
        "Buni hech kim ishlatmayapti — o'chirsangiz bo'ladi."
    )
    static let adviceLeftover = T("Left over", "Ortiqcha")
    static let adviceLeftoverWhy = T(
        "The app that started this has already closed. Best thing to clean up.",
        "Buni ochgan ilova allaqachon yopilgan. Birinchi navbatda shuni tozalang."
    )
    static let adviceInUse = T("In use", "Ishlatilmoqda")
    static let adviceInUseWhy = T(
        "Something is using this right now — leave it alone.",
        "Buni hozir kimdir ishlatyapti — tegmaganingiz ma'qul."
    )
    static let adviceKeep = T("Keep", "Tegmang")
    static let adviceKeepWhy = T(
        "macOS needs this. Quitting it gains nothing — it just starts again.",
        "Bu macOS'ga kerak. Yopsangiz foyda yo'q — o'zi qaytadan ishga tushadi."
    )
    static let appIsOpen = T("App is open", "Ilova ochiq")
    static let appIsOpenWhy = T(
        "Close the app first, otherwise it will just write the cache again.",
        "Avval ilovani yoping, aks holda keshni qaytadan yozadi."
    )

    static func listeningOnPort(_ ports: [Int]) -> T {
        let list = ports.map(String.init).joined(separator: ", ")
        return T("port \(list)", "\(list)-port")
    }

    // Categories
    static let catUserCaches = T("User Caches", "Ilovalar keshi")
    static let catUserCachesSub = T(
        "Rebuildable app caches in ~/Library/Caches",
        "~/Library/Caches ichidagi qayta tiklanadigan kesh"
    )
    static let catLogs = T("Logs & Crash Reports", "Loglar va xato hisobotlari")
    static let catLogsSub = T("Diagnostic logs apps left behind", "Ilovalar qoldirgan texnik yozuvlar")
    static let catXcode = T("Xcode Junk", "Xcode chiqindilari")
    static let catXcodeSub = T(
        "DerivedData, archives and device support files",
        "DerivedData, arxiv va qurilma fayllari"
    )
    static let catDev = T("Developer Caches", "Dasturchi keshi")
    static let catDevSub = T(
        "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…"
    )
    static let catBrowsers = T("Browser Caches", "Brauzer keshi")
    static let catBrowsersSub = T(
        "Cached pages and images your browsers can refetch",
        "Brauzer qayta yuklay oladigan sahifa va rasmlar"
    )
    static let catTrash = T("Trash", "Savat")
    static let catTrashSub = T("Items already in the Trash", "Savatdagi fayllar")
    static let catMail = T("Mail Downloads", "Mail yuklamalari")
    static let catMailSub = T(
        "Attachments Mail.app copied out of messages",
        "Mail ilovasi xatlardan nusxalagan biriktirmalar"
    )
    static let catBackups = T("iOS Device Backups", "iPhone/iPad zaxira nusxalari")
    static let catBackupsSub = T(
        "Local iPhone/iPad backups — check before removing",
        "Kompyuterdagi zaxira nusxalar — o'chirishdan oldin tekshiring"
    )
    static let catInstallers = T("Stale Installers", "Eski o'rnatuvchi fayllar")
    static let catInstallersSub = T(
        "Installers in ~/Downloads older than 60 days",
        "~/Downloads dagi 60 kundan eski o'rnatuvchi fayllar"
    )

    // Large files
    static let largeFilesIntro = T(
        "Track down the files actually eating your disk.",
        "Diskni haqiqatan band qilib turgan fayllarni topadi."
    )
    static let largerThan = T("Larger than", "Kattaligi")
    static let includeLibrary = T("Include ~/Library", "~/Library ni ham")
    static let nothingScanned = T("Nothing scanned yet", "Hali tekshirilmadi")
    static let largeFilesHint = T(
        "Pick a folder and a size threshold, then hit Scan. Results stream in as they are found.",
        "Papka va eng kichik hajmni tanlab, Tekshirish tugmasini bosing. Natijalar topilgani sari chiqaveradi."
    )

    static func scannedFiles(_ visited: Int, _ matches: Int) -> T {
        T(
            "Scanned \(visited) files — \(matches) matches",
            "\(visited) ta fayl ko'rildi — \(matches) ta topildi"
        )
    }

    static func walking(_ folder: String) -> T {
        T("Walking \(folder)…", "\(folder) kezilmoqda…")
    }

    static func noFilesAbove(_ mb: Int) -> T {
        T("No files above \(mb) MB", "\(mb) MB dan katta fayl yo'q")
    }

    static func selectedSize(_ count: Int, _ size: String) -> T {
        T("\(count) selected · \(size)", "\(count) ta tanlandi · \(size)")
    }

    static func confirmTrashFiles(_ count: Int, _ size: String) -> T {
        T(
            "Move \(count) files (\(size)) to the Trash?",
            "\(count) ta fayl (\(size)) Savatga tashlansinmi?"
        )
    }

    // Projects
    static let projectsIntro = T(
        "Dependencies and build output you can delete — they come back with one command.",
        "O'chirsa bo'ladigan kutubxona va yig'ish fayllari — bitta buyruq bilan qaytadi."
    )
    static let staleOnly = T("Only untouched for 3 months", "Faqat 3 oy tegilmaganlari")
    static let selectStale = T("Select stale", "Eskilarini tanlash")
    static let noProjects = T("No projects found here", "Bu yerda loyiha topilmadi")
    static let projectsHint = T(
        "Pick a folder that holds your projects and press Scan. Only folders that sit next to "
            + "a package.json, Cargo.toml, Podfile and the like are offered.",
        "Loyihalaringiz turgan papkani tanlab, Tekshirish ni bosing. Faqat package.json, "
            + "Cargo.toml, Podfile kabi fayllar yonida turgan papkalar ko'rsatiladi."
    )
    static let kindNodeModules = T("dependencies", "kutubxonalar")
    static let kindBuildOutput = T("build output", "yig'ish natijasi")
    static let kindPods = T("CocoaPods", "CocoaPods")
    static let kindGradle = T("Gradle cache", "Gradle keshi")
    static let kindTarget = T("build target", "build target")
    static let kindPython = T("Python files", "Python fayllari")
    static let kindVendor = T("vendor", "vendor")
    static let kindDerivedData = T("Xcode DerivedData", "Xcode DerivedData")

    static func restoreWith(_ command: String) -> T {
        T("comes back with `\(command)`", "`\(command)` bilan qaytadi")
    }

    static func projectsFound(_ projects: Int, _ size: String) -> T {
        T(
            "\(projects) projects · \(size) reclaimable",
            "\(projects) ta loyiha · \(size) bo'shatish mumkin"
        )
    }

    static func lastTouched(_ age: String) -> T {
        T("last touched \(age)", "oxirgi marta \(age)")
    }

    // Disk map
    static let diskMapIntro = T(
        "See where the space actually went — every folder drawn to scale.",
        "Joy qayerga ketganini ko'rsatadi — har bir papka hajmiga yarasha chizilgan."
    )
    static let diskMapHint = T(
        "Pick a folder and press Scan. One pass builds the whole tree, then clicking a "
            + "box opens it instantly.",
        "Papkani tanlab, Tekshirish ni bosing. Bitta o'tishda butun daraxt tuziladi, "
            + "keyin katakni bosishingiz bilan darrov ochiladi."
    )
    static let up = T("Up", "Yuqoriga")
    static let emptyFolder = T("Nothing big enough to draw here", "Bu yerda chizishga arziydigan narsa yo'q")

    static func scanningTree(_ files: Int, _ size: String) -> T {
        T(
            "\(files) files · \(size) measured",
            "\(files) ta fayl · \(size) o'lchandi"
        )
    }

    // Apps
    static let searchApps = T("Search apps", "Ilova qidirish")
    static let appsIntro = T(
        "Everything installed in /Applications and your home folder.",
        "/Applications va uy papkangizga o'rnatilgan barcha ilovalar."
    )
    static let hiddenAppsIntro = T(
        "Menu-bar helpers and apps installed outside the normal places. "
            + "They have no Dock icon, so they are easy to forget.",
        "Menyu satridagi yordamchilar va odatdagi joydan tashqarida o'rnatilgan ilovalar. "
            + "Ular Dock'da ko'rinmaydi, shuning uchun esdan chiqadi."
    )
    static let pickAppTitle = T("Remove an app completely", "Ilovani butunlay o'chirish")
    static let pickAppBody = T(
        "Pick an app to see the caches, preferences and containers it left in your Library — "
            + "then remove all of it in one go.",
        "Ilovani tanlang — u Library'da qoldirgan kesh, sozlama va konteynerlarini ko'rasiz, "
            + "hammasini birdaniga o'chirasiz."
    )
    static let leftovers = T("Support files left behind", "Qolib ketgan yordamchi fayllar")
    static let noLeftovers = T(
        "No leftover files matched this app.",
        "Bu ilovadan qolgan fayl topilmadi."
    )
    static let uninstall = T("Uninstall", "O'chirish")
    static let uninstallNote = T(
        "Quit the app first. Everything goes to the Trash and can be restored.",
        "Avval ilovani yoping. Hammasi Savatga tushadi va qaytarib olinadi."
    )
    static let systemAppNote = T(
        "This is a macOS system app and cannot be removed.",
        "Bu macOS tizim ilovasi — uni o'chirib bo'lmaydi."
    )
    static let badgeMenuBar = T("Menu bar", "Menyu satri")
    static let badgeUnusualPlace = T("Unusual location", "G'ayrioddiy joy")
    static let badgeRunning = T("Running", "Ishlayapti")
    static let badgeSystem = T("System", "Tizim")

    static func foundCount(_ count: Int) -> T {
        T("\(count) found", "\(count) ta topildi")
    }

    static func totalToRemove(_ size: String) -> T {
        T("Total to remove: \(size)", "Jami o'chiriladi: \(size)")
    }

    static func confirmUninstall(_ name: String, _ count: Int) -> T {
        T(
            "Move \(name) and \(count) support files to the Trash?",
            "\(name) va \(count) ta yordamchi fayl Savatga tashlansinmi?"
        )
    }

    static func appsFound(_ count: Int) -> T {
        T("\(count) apps", "\(count) ta ilova")
    }

    // Processes
    static let processesIntro = T(
        "Apps and helpers running right now, heaviest first.",
        "Hozir ishlab turgan ilova va yordamchilar — og'irlaridan boshlab."
    )
    static let onlyBackground = T("Only background ones", "Faqat fondagilar")
    static let quit = T("Quit", "Yopish")
    static let memory = T("Memory", "Xotira")
    static let noDockIcon = T("No Dock icon", "Dock'da yo'q")
    static let quitNote = T(
        "Quitting asks the app to close normally — unsaved work is kept.",
        "Yopish so'rovi ilovaga odatdagidek yopilishni aytadi — saqlanmagan ish yo'qolmaydi."
    )

    static func confirmQuit(_ name: String) -> T {
        T("Quit \(name)?", "\(name) yopilsinmi?")
    }

    static func processSummary(_ count: Int, _ memory: String) -> T {
        T("\(count) processes · \(memory)", "\(count) ta jarayon · \(memory)")
    }

    // Services
    static let servicesIntro = T(
        "Programs macOS starts on its own — at login or in the background.",
        "macOS o'zi ishga tushiradigan dasturlar — tizimga kirganda yoki fonda."
    )
    static let showAppleServices = T("Show Apple services", "Apple xizmatlarini ko'rsatish")
    static let loaded = T("Active", "Faol")
    static let notLoaded = T("Inactive", "Faol emas")
    static let startsAtLogin = T("Starts at login", "Kirishda ishga tushadi")
    static let scopeUser = T("Yours", "Sizniki")
    static let scopeAdmin = T("All users", "Barcha foydalanuvchilar")
    static let scopeSystem = T("macOS", "macOS")
    static let disableAndTrash = T("Turn off & remove", "O'chirib, Savatga")
    static let readOnlyService = T(
        "Needs an administrator — MacBroom will only show you where it lives.",
        "Administrator huquqi kerak — MacBroom faqat joyini ko'rsatadi."
    )
    static let serviceNote = T(
        "The service is stopped and its file goes to the Trash. Put it back to undo.",
        "Xizmat to'xtatiladi va fayli Savatga tushadi. Qaytarsangiz tiklanadi."
    )
    static let noServices = T("No services here", "Bu yerda xizmat yo'q")

    static func confirmDisable(_ label: String) -> T {
        T("Turn off \(label)?", "\(label) o'chirilsinmi?")
    }

    static func servicesSummary(_ total: Int, _ active: Int) -> T {
        T("\(total) services · \(active) active", "\(total) ta xizmat · \(active) tasi faol")
    }
}
