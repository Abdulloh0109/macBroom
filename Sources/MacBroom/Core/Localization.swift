import Foundation

enum Language: String, CaseIterable, Identifiable {
    case uz
    case en
    case ru
    case tr
    case de
    case es
    case fr
    case zh

    var id: String { rawValue }

    var short: String { rawValue.uppercased() }

    var flag: String {
        switch self {
        case .uz: return "🇺🇿"
        case .en: return "🇬🇧"
        case .ru: return "🇷🇺"
        case .tr: return "🇹🇷"
        case .de: return "🇩🇪"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .zh: return "🇨🇳"
        }
    }

    /// Always written the way speakers of that language write it themselves.
    var title: String {
        switch self {
        case .uz: return "O'zbekcha"
        case .en: return "English"
        case .ru: return "Русский"
        case .tr: return "Türkçe"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .fr: return "Français"
        case .zh: return "中文"
        }
    }
}

/// One phrase in every language the app speaks.
///
/// A dictionary rather than eight positional arguments: at eight languages the
/// positional form becomes unreadable and easy to mis-order. Completeness is
/// checked instead by `Scripts/check_translations.swift`, which reads this file
/// and fails if any entry is missing a language.
struct T {
    private let table: [Language: String]

    init(_ table: [Language: String]) {
        self.table = table
    }

    func callAsFunction(_ language: Language) -> String {
        table[language] ?? table[.en] ?? ""
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
        // No stored choice: follow the system, fall back to Uzbek.
        let system = Locale.preferredLanguages.first.flatMap { tag -> Language? in
            let code = String(tag.prefix(2)).lowercased()
            return Language(rawValue: code)
        }
        language = stored.flatMap(Language.init(rawValue:)) ?? system ?? .uz
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
    static let appTagline = T([
        .en: "Free your disk", .uz: "Diskingizni bo'shating", .ru: "Освободите диск",
        .tr: "Diskinizi boşaltın", .de: "Platz auf der Festplatte", .es: "Libera tu disco",
        .fr: "Libérez votre disque", .zh: "释放磁盘空间",
    ])
    static let refresh = T([
        .en: "Refresh", .uz: "Yangilash", .ru: "Обновить", .tr: "Yenile",
        .de: "Aktualisieren", .es: "Actualizar", .fr: "Actualiser", .zh: "刷新",
    ])
    static let free = T([
        .en: "free", .uz: "bo'sh", .ru: "свободно", .tr: "boş",
        .de: "frei", .es: "libre", .fr: "libre", .zh: "可用",
    ])
    static let cancel = T([
        .en: "Cancel", .uz: "Bekor qilish", .ru: "Отмена", .tr: "Vazgeç",
        .de: "Abbrechen", .es: "Cancelar", .fr: "Annuler", .zh: "取消",
    ])
    static let stop = T([
        .en: "Stop", .uz: "To'xtatish", .ru: "Стоп", .tr: "Durdur",
        .de: "Stoppen", .es: "Detener", .fr: "Arrêter", .zh: "停止",
    ])
    static let none = T([
        .en: "None", .uz: "Hech biri", .ru: "Ничего", .tr: "Hiçbiri",
        .de: "Keine", .es: "Ninguno", .fr: "Aucun", .zh: "全不选",
    ])
    static let revealInFinder = T([
        .en: "Show in Finder", .uz: "Finder'da ochish", .ru: "Показать в Finder",
        .tr: "Finder'da göster", .de: "Im Finder zeigen", .es: "Mostrar en Finder",
        .fr: "Afficher dans le Finder", .zh: "在访达中显示",
    ])
    static let loading = T([
        .en: "Loading…", .uz: "Yuklanmoqda…", .ru: "Загрузка…", .tr: "Yükleniyor…",
        .de: "Wird geladen…", .es: "Cargando…", .fr: "Chargement…", .zh: "加载中…",
    ])
    static let language = T([
        .en: "Language", .uz: "Til", .ru: "Язык", .tr: "Dil",
        .de: "Sprache", .es: "Idioma", .fr: "Langue", .zh: "语言",
    ])

    static func diskUsed(_ used: String, _ total: String) -> T {
        T([
            .en: "\(used) of \(total) used", .uz: "\(total) dan \(used) band",
            .ru: "занято \(used) из \(total)", .tr: "\(total) alanın \(used) dolu",
            .de: "\(used) von \(total) belegt", .es: "\(used) de \(total) usados",
            .fr: "\(used) sur \(total) utilisés", .zh: "已用 \(used)，共 \(total)",
        ])
    }

    static func purgeableHint(_ size: String) -> T {
        T([
            .en: "+\(size) macOS can reclaim on demand",
            .uz: "+\(size) ni macOS kerak bo'lganda bo'shatadi",
            .ru: "+\(size) macOS освободит при необходимости",
            .tr: "+\(size) macOS gerektiğinde boşaltır",
            .de: "+\(size) gibt macOS bei Bedarf frei",
            .es: "+\(size) que macOS puede liberar si hace falta",
            .fr: "+\(size) que macOS peut libérer au besoin",
            .zh: "另有 \(size) 可由 macOS 按需释放",
        ])
    }

    static func items(_ count: Int) -> T {
        T([
            .en: "\(count) items", .uz: "\(count) ta", .ru: "\(count) шт.",
            .tr: "\(count) öğe", .de: "\(count) Objekte", .es: "\(count) elementos",
            .fr: "\(count) éléments", .zh: "\(count) 项",
        ])
    }

    static func moreItems(_ count: Int) -> T {
        T([
            .en: "+ \(count) more", .uz: "yana \(count) ta", .ru: "ещё \(count)",
            .tr: "\(count) tane daha", .de: "+ \(count) weitere", .es: "+ \(count) más",
            .fr: "+ \(count) autres", .zh: "还有 \(count) 项",
        ])
    }

    // Features
    static let smartScan = T([
        .en: "Smart Scan", .uz: "Aqlli tekshiruv", .ru: "Умная проверка",
        .tr: "Akıllı Tarama", .de: "Intelligenter Scan", .es: "Análisis inteligente",
        .fr: "Analyse intelligente", .zh: "智能扫描",
    ])
    static let largeFiles = T([
        .en: "Large & Old Files", .uz: "Katta va eski fayllar", .ru: "Большие и старые файлы",
        .tr: "Büyük ve Eski Dosyalar", .de: "Große & alte Dateien",
        .es: "Archivos grandes y antiguos", .fr: "Fichiers volumineux et anciens",
        .zh: "大文件和旧文件",
    ])
    static let apps = T([
        .en: "Installed Apps", .uz: "O'rnatilgan ilovalar", .ru: "Установленные программы",
        .tr: "Yüklü Uygulamalar", .de: "Installierte Apps", .es: "Apps instaladas",
        .fr: "Apps installées", .zh: "已安装应用",
    ])
    static let hiddenApps = T([
        .en: "Hidden Apps", .uz: "Yashirin ilovalar", .ru: "Скрытые программы",
        .tr: "Gizli Uygulamalar", .de: "Versteckte Apps", .es: "Apps ocultas",
        .fr: "Apps masquées", .zh: "隐藏应用",
    ])
    static let processes = T([
        .en: "Running in Background", .uz: "Fonda ishlayotganlar", .ru: "Работает в фоне",
        .tr: "Arka Planda Çalışanlar", .de: "Im Hintergrund", .es: "En segundo plano",
        .fr: "En arrière-plan", .zh: "后台运行",
    ])
    static let services = T([
        .en: "Startup Services", .uz: "Avtomatik xizmatlar", .ru: "Автозапуск",
        .tr: "Başlangıç Servisleri", .de: "Startobjekte", .es: "Servicios de inicio",
        .fr: "Services au démarrage", .zh: "开机启动项",
    ])
    static let projects = T([
        .en: "Developer Projects", .uz: "Loyihalar", .ru: "Проекты",
        .tr: "Projeler", .de: "Entwicklerprojekte", .es: "Proyectos",
        .fr: "Projets", .zh: "开发项目",
    ])
    static let diskMap = T([
        .en: "Disk Map", .uz: "Disk xaritasi", .ru: "Карта диска",
        .tr: "Disk Haritası", .de: "Speicherkarte", .es: "Mapa del disco",
        .fr: "Carte du disque", .zh: "磁盘地图",
    ])

    // Smart Scan
    static let scan = T([
        .en: "Scan", .uz: "Tekshirish", .ru: "Проверить", .tr: "Tara",
        .de: "Scannen", .es: "Analizar", .fr: "Analyser", .zh: "扫描",
    ])
    static let rescan = T([
        .en: "Rescan", .uz: "Qayta tekshirish", .ru: "Проверить снова", .tr: "Yeniden tara",
        .de: "Erneut scannen", .es: "Analizar de nuevo", .fr: "Relancer l'analyse",
        .zh: "重新扫描",
    ])
    static let smartScanIntro = T([
        .en: "Find caches, logs and build junk you can safely reclaim.",
        .uz: "Kesh, log va dasturchi chiqindilarini topib, disk joyini bo'shatadi.",
        .ru: "Находит кэш, журналы и мусор сборки, который можно спокойно удалить.",
        .tr: "Önbellek, günlük ve derleme artıklarını bulup güvenle temizler.",
        .de: "Findet Caches, Logs und Build-Müll, den Sie gefahrlos löschen können.",
        .es: "Encuentra cachés, registros y restos de compilación que puedes borrar sin riesgo.",
        .fr: "Trouve les caches, journaux et résidus de compilation que vous pouvez supprimer sans risque.",
        .zh: "查找可安全清理的缓存、日志和构建垃圾。",
    ])
    static let searchingJunk = T([
        .en: "Looking for junk…", .uz: "Keraksiz fayllar qidirilmoqda…", .ru: "Поиск мусора…",
        .tr: "Gereksiz dosyalar aranıyor…", .de: "Suche nach Datenmüll…",
        .es: "Buscando archivos innecesarios…", .fr: "Recherche de fichiers inutiles…",
        .zh: "正在查找垃圾文件…",
    ])
    static let scanComplete = T([
        .en: "Scan complete", .uz: "Tekshiruv tugadi", .ru: "Проверка завершена",
        .tr: "Tarama tamamlandı", .de: "Scan abgeschlossen", .es: "Análisis completado",
        .fr: "Analyse terminée", .zh: "扫描完成",
    ])
    static let nothingToClean = T([
        .en: "Nothing to clean", .uz: "Tozalaydigan narsa yo'q", .ru: "Чистить нечего",
        .tr: "Temizlenecek bir şey yok", .de: "Nichts zu bereinigen",
        .es: "No hay nada que limpiar", .fr: "Rien à nettoyer", .zh: "无需清理",
    ])
    static let readyTitle = T([
        .en: "Ready when you are", .uz: "Boshlashga tayyor", .ru: "Готово к запуску",
        .tr: "Başlamaya hazır", .de: "Bereit, wenn Sie es sind", .es: "Listo cuando quieras",
        .fr: "Prêt quand vous voulez", .zh: "随时可以开始",
    ])
    static let readyBody = T([
        .en: "MacBroom looks through caches, logs, developer build artifacts and the Trash. "
            + "Everything it removes goes to the Trash first, so you can always put it back.",
        .uz: "MacBroom kesh, log, dasturchi fayllari va Savatni ko'rib chiqadi. "
            + "O'chirilgan hamma narsa avval Savatga tushadi — istalgan payt qaytarib olasiz.",
        .ru: "MacBroom просматривает кэш, журналы, файлы сборки и Корзину. "
            + "Всё удалённое сначала попадает в Корзину, так что это всегда можно вернуть.",
        .tr: "MacBroom önbellekleri, günlükleri, derleme dosyalarını ve Çöp Kutusu'nu tarar. "
            + "Silinen her şey önce Çöp Kutusu'na gider, istediğiniz zaman geri alabilirsiniz.",
        .de: "MacBroom durchsucht Caches, Logs, Build-Artefakte und den Papierkorb. "
            + "Alles Entfernte landet zuerst im Papierkorb und lässt sich zurücklegen.",
        .es: "MacBroom revisa cachés, registros, artefactos de compilación y la Papelera. "
            + "Todo lo que elimina va primero a la Papelera, así que siempre puedes recuperarlo.",
        .fr: "MacBroom parcourt les caches, journaux, artefacts de compilation et la Corbeille. "
            + "Tout ce qui est supprimé passe d'abord par la Corbeille, vous pouvez donc le restaurer.",
        .zh: "MacBroom 会检查缓存、日志、开发构建产物和废纸篓。所有清理的内容都会先进入废纸篓，随时可以还原。",
    ])
    static let allCleanTitle = T([
        .en: "All clean", .uz: "Hammasi toza", .ru: "Всё чисто", .tr: "Her şey temiz",
        .de: "Alles sauber", .es: "Todo limpio", .fr: "Tout est propre", .zh: "已经很干净",
    ])
    static let allCleanBody = T([
        .en: "Nothing worth removing was found in the scanned locations.",
        .uz: "Tekshirilgan joylarda o'chirishga arziydigan narsa topilmadi.",
        .ru: "В проверенных местах не нашлось ничего, что стоило бы удалять.",
        .tr: "Taranan yerlerde silmeye değer bir şey bulunamadı.",
        .de: "An den geprüften Orten wurde nichts Löschenswertes gefunden.",
        .es: "No se encontró nada que merezca la pena borrar en las ubicaciones analizadas.",
        .fr: "Rien qui vaille la peine d'être supprimé dans les emplacements analysés.",
        .zh: "在扫描的位置未发现值得清理的内容。",
    ])
    static let safeOnly = T([
        .en: "Safe only", .uz: "Faqat xavfsizlari", .ru: "Только безопасные",
        .tr: "Yalnızca güvenliler", .de: "Nur sichere", .es: "Solo lo seguro",
        .fr: "Seulement les sûrs", .zh: "仅安全项",
    ])
    static let moveToTrash = T([
        .en: "Move to Trash", .uz: "Savatga tashlash", .ru: "В Корзину",
        .tr: "Çöp Kutusu'na taşı", .de: "In den Papierkorb", .es: "Mover a la Papelera",
        .fr: "Mettre à la Corbeille", .zh: "移到废纸篓",
    ])
    static let cleaning = T([
        .en: "Cleaning…", .uz: "Tozalanmoqda…", .ru: "Очистка…", .tr: "Temizleniyor…",
        .de: "Wird bereinigt…", .es: "Limpiando…", .fr: "Nettoyage…", .zh: "正在清理…",
    ])
    static let trashNote = T([
        .en: "Nothing is deleted permanently — you can restore items from the Trash.",
        .uz: "Hech narsa butunlay o'chmaydi — Savatdan qaytarib olsangiz bo'ladi.",
        .ru: "Ничего не удаляется навсегда — файлы можно вернуть из Корзины.",
        .tr: "Hiçbir şey kalıcı olarak silinmez — Çöp Kutusu'ndan geri alabilirsiniz.",
        .de: "Nichts wird endgültig gelöscht — Sie können alles aus dem Papierkorb zurückholen.",
        .es: "Nada se borra de forma permanente: puedes restaurarlo desde la Papelera.",
        .fr: "Rien n'est supprimé définitivement — vous pouvez tout restaurer depuis la Corbeille.",
        .zh: "不会永久删除，随时可从废纸篓还原。",
    ])

    static func measuring(_ done: Int, _ total: Int) -> T {
        T([
            .en: "Measuring… \(done)/\(total)", .uz: "O'lchanmoqda… \(done)/\(total)",
            .ru: "Измерение… \(done)/\(total)", .tr: "Ölçülüyor… \(done)/\(total)",
            .de: "Wird gemessen… \(done)/\(total)", .es: "Midiendo… \(done)/\(total)",
            .fr: "Mesure… \(done)/\(total)", .zh: "正在测量… \(done)/\(total)",
        ])
    }

    static func reclaimable(_ size: String, _ count: Int) -> T {
        T([
            .en: "\(size) reclaimable across \(count) categories.",
            .uz: "\(count) ta bo'limda \(size) bo'shatish mumkin.",
            .ru: "\(size) можно освободить в \(count) категориях.",
            .tr: "\(count) kategoride \(size) boşaltılabilir.",
            .de: "\(size) in \(count) Kategorien freigebbar.",
            .es: "\(size) recuperables en \(count) categorías.",
            .fr: "\(size) récupérables dans \(count) catégories.",
            .zh: "\(count) 个类别中可释放 \(size)。",
        ])
    }

    static func freed(_ size: String) -> T {
        T([
            .en: "Freed \(size)", .uz: "\(size) bo'shatildi", .ru: "Освобождено \(size)",
            .tr: "\(size) boşaltıldı", .de: "\(size) freigegeben", .es: "Liberados \(size)",
            .fr: "\(size) libérés", .zh: "已释放 \(size)",
        ])
    }

    static func freedNothingLeft(_ size: String) -> T {
        T([
            .en: "Freed \(size). Nothing left to clean.",
            .uz: "\(size) bo'shatildi. Boshqa tozalaydigan narsa qolmadi.",
            .ru: "Освобождено \(size). Больше чистить нечего.",
            .tr: "\(size) boşaltıldı. Temizlenecek başka bir şey kalmadı.",
            .de: "\(size) freigegeben. Es gibt nichts mehr zu bereinigen.",
            .es: "Liberados \(size). No queda nada que limpiar.",
            .fr: "\(size) libérés. Il ne reste rien à nettoyer.",
            .zh: "已释放 \(size)，没有其他可清理的内容。",
        ])
    }

    static func selectedItems(_ count: Int) -> T {
        T([
            .en: "\(count) items selected", .uz: "\(count) ta element tanlandi",
            .ru: "Выбрано \(count)", .tr: "\(count) öğe seçildi",
            .de: "\(count) Objekte ausgewählt", .es: "\(count) elementos seleccionados",
            .fr: "\(count) éléments sélectionnés", .zh: "已选 \(count) 项",
        ])
    }

    static func confirmTrash(_ count: Int, _ size: String) -> T {
        T([
            .en: "Move \(count) items (\(size)) to the Trash?",
            .uz: "\(count) ta element (\(size)) Savatga tashlansinmi?",
            .ru: "Переместить \(count) объектов (\(size)) в Корзину?",
            .tr: "\(count) öğe (\(size)) Çöp Kutusu'na taşınsın mı?",
            .de: "\(count) Objekte (\(size)) in den Papierkorb legen?",
            .es: "¿Mover \(count) elementos (\(size)) a la Papelera?",
            .fr: "Mettre \(count) éléments (\(size)) à la Corbeille ?",
            .zh: "将 \(count) 项（\(size)）移到废纸篓？",
        ])
    }

    static func movingToTrash(_ count: Int) -> T {
        T([
            .en: "Moving \(count) items to the Trash…",
            .uz: "\(count) ta element Savatga ko'chirilmoqda…",
            .ru: "Перемещение \(count) объектов в Корзину…",
            .tr: "\(count) öğe Çöp Kutusu'na taşınıyor…",
            .de: "\(count) Objekte werden in den Papierkorb gelegt…",
            .es: "Moviendo \(count) elementos a la Papelera…",
            .fr: "Déplacement de \(count) éléments vers la Corbeille…",
            .zh: "正在将 \(count) 项移到废纸篓…",
        ])
    }

    static func couldNotRemove(_ count: Int) -> T {
        T([
            .en: "\(count) item(s) could not be removed",
            .uz: "\(count) ta elementni o'chirib bo'lmadi",
            .ru: "Не удалось удалить \(count) объект(ов)",
            .tr: "\(count) öğe silinemedi",
            .de: "\(count) Objekt(e) konnten nicht entfernt werden",
            .es: "No se pudieron eliminar \(count) elemento(s)",
            .fr: "\(count) élément(s) n'ont pas pu être supprimés",
            .zh: "有 \(count) 项无法移除",
        ])
    }

    // Risk
    static let riskSafe = T([
        .en: "Safe", .uz: "Xavfsiz", .ru: "Безопасно", .tr: "Güvenli",
        .de: "Sicher", .es: "Seguro", .fr: "Sûr", .zh: "安全",
    ])
    static let riskReview = T([
        .en: "Check", .uz: "Tekshiring", .ru: "Проверьте", .tr: "Kontrol edin",
        .de: "Prüfen", .es: "Revisar", .fr: "À vérifier", .zh: "请确认",
    ])

    // Advice
    static let adviceRemovable = T([
        .en: "Can remove", .uz: "O'chirish mumkin", .ru: "Можно удалить",
        .tr: "Silinebilir", .de: "Entfernbar", .es: "Se puede borrar",
        .fr: "Supprimable", .zh: "可以删除",
    ])
    static let adviceRemovableWhy = T([
        .en: "Nothing is using it — removing it is safe.",
        .uz: "Buni hech kim ishlatmayapti — o'chirsangiz bo'ladi.",
        .ru: "Этим ничто не пользуется — удалять безопасно.",
        .tr: "Bunu kullanan yok — silmek güvenli.",
        .de: "Nichts nutzt das — Entfernen ist gefahrlos.",
        .es: "Nada lo está usando: borrarlo es seguro.",
        .fr: "Rien ne l'utilise — la suppression est sans risque.",
        .zh: "没有任何程序在使用，删除是安全的。",
    ])
    static let adviceLeftover = T([
        .en: "Left over", .uz: "Ortiqcha", .ru: "Остаток", .tr: "Artık",
        .de: "Überbleibsel", .es: "Sobrante", .fr: "Résidu", .zh: "残留",
    ])
    static let adviceLeftoverWhy = T([
        .en: "The app that started this has already closed. Best thing to clean up.",
        .uz: "Buni ochgan ilova allaqachon yopilgan. Birinchi navbatda shuni tozalang.",
        .ru: "Программа, которая это запустила, уже закрыта. Чистить в первую очередь.",
        .tr: "Bunu başlatan uygulama çoktan kapandı. Önce bunu temizleyin.",
        .de: "Die zugehörige App ist längst beendet. Am besten zuerst aufräumen.",
        .es: "La app que lo inició ya se cerró. Es lo primero que conviene limpiar.",
        .fr: "L'app qui l'a lancé est déjà fermée. À nettoyer en priorité.",
        .zh: "启动它的应用已经关闭，最该清理的就是这些。",
    ])
    static let adviceInUse = T([
        .en: "In use", .uz: "Ishlatilmoqda", .ru: "Используется", .tr: "Kullanımda",
        .de: "In Benutzung", .es: "En uso", .fr: "Utilisé", .zh: "使用中",
    ])
    static let adviceInUseWhy = T([
        .en: "Something is using this right now — leave it alone.",
        .uz: "Buni hozir kimdir ishlatyapti — tegmaganingiz ma'qul.",
        .ru: "Сейчас это кем-то используется — лучше не трогать.",
        .tr: "Şu anda bir şey bunu kullanıyor — dokunmayın.",
        .de: "Etwas nutzt das gerade — besser nicht anrühren.",
        .es: "Algo lo está usando ahora mismo: mejor no tocarlo.",
        .fr: "Quelque chose l'utilise en ce moment — mieux vaut ne pas y toucher.",
        .zh: "当前有程序正在使用，建议不要动。",
    ])
    static let adviceKeep = T([
        .en: "Keep", .uz: "Tegmang", .ru: "Не трогать", .tr: "Dokunmayın",
        .de: "Behalten", .es: "Conservar", .fr: "À conserver", .zh: "请保留",
    ])
    static let adviceKeepWhy = T([
        .en: "macOS needs this. Quitting it gains nothing — it just starts again.",
        .uz: "Bu macOS'ga kerak. Yopsangiz foyda yo'q — o'zi qaytadan ishga tushadi.",
        .ru: "Это нужно macOS. Завершать бессмысленно — процесс запустится снова.",
        .tr: "Bu macOS için gerekli. Kapatmanın faydası yok — yeniden başlar.",
        .de: "Das braucht macOS. Beenden bringt nichts — es startet einfach neu.",
        .es: "macOS lo necesita. Cerrarlo no sirve de nada: vuelve a arrancar.",
        .fr: "macOS en a besoin. Le quitter ne sert à rien — il redémarre aussitôt.",
        .zh: "macOS 需要它。结束也没用，系统会立刻重新启动它。",
    ])
    static let appIsOpen = T([
        .en: "App is open", .uz: "Ilova ochiq", .ru: "Программа открыта",
        .tr: "Uygulama açık", .de: "App ist offen", .es: "La app está abierta",
        .fr: "L'app est ouverte", .zh: "应用正在运行",
    ])
    static let appIsOpenWhy = T([
        .en: "Close the app first, otherwise it will just write the cache again.",
        .uz: "Avval ilovani yoping, aks holda keshni qaytadan yozadi.",
        .ru: "Сначала закройте программу, иначе она снова создаст кэш.",
        .tr: "Önce uygulamayı kapatın, yoksa önbelleği yeniden oluşturur.",
        .de: "Schließen Sie die App zuerst, sonst legt sie den Cache gleich wieder an.",
        .es: "Cierra la app primero o volverá a escribir la caché.",
        .fr: "Fermez d'abord l'app, sinon elle réécrira le cache aussitôt.",
        .zh: "请先退出该应用，否则缓存会立刻被重新写入。",
    ])

    static func listeningOnPort(_ ports: [Int]) -> T {
        let list = ports.map(String.init).joined(separator: ", ")
        return T([
            .en: "port \(list)", .uz: "\(list)-port", .ru: "порт \(list)",
            .tr: "\(list) portu", .de: "Port \(list)", .es: "puerto \(list)",
            .fr: "port \(list)", .zh: "端口 \(list)",
        ])
    }

    // Categories
    static let catUserCaches = T([
        .en: "User Caches", .uz: "Ilovalar keshi", .ru: "Кэш программ",
        .tr: "Uygulama önbelleği", .de: "App-Caches", .es: "Cachés de apps",
        .fr: "Caches des apps", .zh: "应用缓存",
    ])
    static let catUserCachesSub = T([
        .en: "Rebuildable app caches in ~/Library/Caches",
        .uz: "~/Library/Caches ichidagi qayta tiklanadigan kesh",
        .ru: "Восстанавливаемый кэш в ~/Library/Caches",
        .tr: "~/Library/Caches içindeki yeniden oluşturulabilir önbellek",
        .de: "Wiederherstellbare Caches in ~/Library/Caches",
        .es: "Cachés regenerables en ~/Library/Caches",
        .fr: "Caches régénérables dans ~/Library/Caches",
        .zh: "~/Library/Caches 中可重建的缓存",
    ])
    static let catLogs = T([
        .en: "Logs & Crash Reports", .uz: "Loglar va xato hisobotlari",
        .ru: "Журналы и отчёты о сбоях", .tr: "Günlükler ve çökme raporları",
        .de: "Logs & Absturzberichte", .es: "Registros e informes de fallos",
        .fr: "Journaux et rapports de plantage", .zh: "日志与崩溃报告",
    ])
    static let catLogsSub = T([
        .en: "Diagnostic logs apps left behind", .uz: "Ilovalar qoldirgan texnik yozuvlar",
        .ru: "Диагностические записи, оставленные программами",
        .tr: "Uygulamaların bıraktığı tanılama kayıtları",
        .de: "Diagnoseprotokolle, die Apps hinterlassen haben",
        .es: "Registros de diagnóstico que dejaron las apps",
        .fr: "Journaux de diagnostic laissés par les apps",
        .zh: "应用遗留的诊断日志",
    ])
    static let catXcode = T([
        .en: "Xcode Junk", .uz: "Xcode chiqindilari", .ru: "Мусор Xcode",
        .tr: "Xcode artıkları", .de: "Xcode-Müll", .es: "Restos de Xcode",
        .fr: "Résidus Xcode", .zh: "Xcode 垃圾",
    ])
    static let catXcodeSub = T([
        .en: "DerivedData, archives and device support files",
        .uz: "DerivedData, arxiv va qurilma fayllari",
        .ru: "DerivedData, архивы и файлы поддержки устройств",
        .tr: "DerivedData, arşivler ve aygıt destek dosyaları",
        .de: "DerivedData, Archive und Geräte-Support-Dateien",
        .es: "DerivedData, archivos y soporte de dispositivos",
        .fr: "DerivedData, archives et fichiers de support d'appareils",
        .zh: "DerivedData、归档和设备支持文件",
    ])
    static let catDev = T([
        .en: "Developer Caches", .uz: "Dasturchi keshi", .ru: "Кэш разработчика",
        .tr: "Geliştirici önbelleği", .de: "Entwickler-Caches", .es: "Cachés de desarrollo",
        .fr: "Caches de développement", .zh: "开发缓存",
    ])
    static let catDevSub = T([
        .en: "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        .uz: "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        .ru: "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        .tr: "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        .de: "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        .es: "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        .fr: "npm, yarn, pnpm, CocoaPods, Homebrew, Gradle, pip…",
        .zh: "npm、yarn、pnpm、CocoaPods、Homebrew、Gradle、pip…",
    ])
    static let catBrowsers = T([
        .en: "Browser Caches", .uz: "Brauzer keshi", .ru: "Кэш браузеров",
        .tr: "Tarayıcı önbelleği", .de: "Browser-Caches", .es: "Cachés del navegador",
        .fr: "Caches des navigateurs", .zh: "浏览器缓存",
    ])
    static let catBrowsersSub = T([
        .en: "Cached pages and images your browsers can refetch",
        .uz: "Brauzer qayta yuklay oladigan sahifa va rasmlar",
        .ru: "Страницы и картинки, которые браузер загрузит заново",
        .tr: "Tarayıcının yeniden indirebileceği sayfa ve görseller",
        .de: "Seiten und Bilder, die Ihr Browser erneut laden kann",
        .es: "Páginas e imágenes que el navegador puede volver a descargar",
        .fr: "Pages et images que le navigateur peut retélécharger",
        .zh: "浏览器可重新下载的页面和图片",
    ])
    static let catTrash = T([
        .en: "Trash", .uz: "Savat", .ru: "Корзина", .tr: "Çöp Kutusu",
        .de: "Papierkorb", .es: "Papelera", .fr: "Corbeille", .zh: "废纸篓",
    ])
    static let catTrashSub = T([
        .en: "Items already in the Trash", .uz: "Savatdagi fayllar",
        .ru: "То, что уже лежит в Корзине", .tr: "Çöp Kutusu'ndaki dosyalar",
        .de: "Was bereits im Papierkorb liegt", .es: "Lo que ya está en la Papelera",
        .fr: "Ce qui est déjà dans la Corbeille", .zh: "已在废纸篓中的内容",
    ])
    static let catMail = T([
        .en: "Mail Downloads", .uz: "Mail yuklamalari", .ru: "Загрузки Почты",
        .tr: "Mail indirmeleri", .de: "Mail-Downloads", .es: "Descargas de Mail",
        .fr: "Téléchargements de Mail", .zh: "邮件下载",
    ])
    static let catMailSub = T([
        .en: "Attachments Mail.app copied out of messages",
        .uz: "Mail ilovasi xatlardan nusxalagan biriktirmalar",
        .ru: "Вложения, скопированные Почтой из писем",
        .tr: "Mail'in iletilerden çıkardığı ekler",
        .de: "Anhänge, die Mail aus Nachrichten kopiert hat",
        .es: "Adjuntos que Mail copió de los mensajes",
        .fr: "Pièces jointes copiées par Mail depuis les messages",
        .zh: "邮件从信件中复制出的附件",
    ])
    static let catBackups = T([
        .en: "iOS Device Backups", .uz: "iPhone/iPad zaxira nusxalari",
        .ru: "Резервные копии iPhone/iPad", .tr: "iPhone/iPad yedekleri",
        .de: "iOS-Gerätesicherungen", .es: "Copias de seguridad de iOS",
        .fr: "Sauvegardes d'appareils iOS", .zh: "iOS 设备备份",
    ])
    static let catBackupsSub = T([
        .en: "Local iPhone/iPad backups — check before removing",
        .uz: "Kompyuterdagi zaxira nusxalar — o'chirishdan oldin tekshiring",
        .ru: "Локальные копии iPhone/iPad — проверьте перед удалением",
        .tr: "Bilgisayardaki iPhone/iPad yedekleri — silmeden önce kontrol edin",
        .de: "Lokale iPhone/iPad-Backups — vor dem Löschen prüfen",
        .es: "Copias locales de iPhone/iPad: revísalas antes de borrar",
        .fr: "Sauvegardes locales iPhone/iPad — à vérifier avant suppression",
        .zh: "本地 iPhone/iPad 备份 — 删除前请确认",
    ])
    static let catInstallers = T([
        .en: "Stale Installers", .uz: "Eski o'rnatuvchi fayllar", .ru: "Старые установщики",
        .tr: "Eski kurulum dosyaları", .de: "Alte Installationsdateien",
        .es: "Instaladores antiguos", .fr: "Vieux installeurs", .zh: "过期安装包",
    ])
    static let catInstallersSub = T([
        .en: "Installers in ~/Downloads older than 60 days",
        .uz: "~/Downloads dagi 60 kundan eski o'rnatuvchi fayllar",
        .ru: "Установщики в ~/Downloads старше 60 дней",
        .tr: "~/Downloads içinde 60 günden eski kurulum dosyaları",
        .de: "Installer in ~/Downloads, älter als 60 Tage",
        .es: "Instaladores en ~/Downloads de más de 60 días",
        .fr: "Installeurs dans ~/Downloads de plus de 60 jours",
        .zh: "~/Downloads 中超过 60 天的安装包",
    ])

    // Large files
    static let largeFilesIntro = T([
        .en: "Track down the files actually eating your disk.",
        .uz: "Diskni haqiqatan band qilib turgan fayllarni topadi.",
        .ru: "Находит файлы, которые действительно занимают диск.",
        .tr: "Diski gerçekten dolduran dosyaları bulur.",
        .de: "Findet die Dateien, die Ihren Speicher wirklich belegen.",
        .es: "Localiza los archivos que de verdad ocupan tu disco.",
        .fr: "Repère les fichiers qui occupent réellement votre disque.",
        .zh: "找出真正占用磁盘的文件。",
    ])
    static let largerThan = T([
        .en: "Larger than", .uz: "Kattaligi", .ru: "Больше чем", .tr: "Şundan büyük",
        .de: "Größer als", .es: "Mayor que", .fr: "Plus grand que", .zh: "大于",
    ])
    static let includeLibrary = T([
        .en: "Include ~/Library", .uz: "~/Library ni ham", .ru: "Включая ~/Library",
        .tr: "~/Library dahil", .de: "~/Library einbeziehen", .es: "Incluir ~/Library",
        .fr: "Inclure ~/Library", .zh: "包含 ~/Library",
    ])
    static let nothingScanned = T([
        .en: "Nothing scanned yet", .uz: "Hali tekshirilmadi", .ru: "Пока ничего не проверено",
        .tr: "Henüz tarama yapılmadı", .de: "Noch nichts gescannt",
        .es: "Aún no se ha analizado nada", .fr: "Rien n'a encore été analysé",
        .zh: "尚未扫描",
    ])
    static let largeFilesHint = T([
        .en: "Pick a folder and a size threshold, then hit Scan. Results stream in as they are found.",
        .uz: "Papka va eng kichik hajmni tanlab, Tekshirish tugmasini bosing. Natijalar topilgani sari chiqaveradi.",
        .ru: "Выберите папку и минимальный размер, затем нажмите Проверить. Результаты появляются по мере поиска.",
        .tr: "Bir klasör ve en küçük boyutu seçip Tara'ya basın. Sonuçlar bulundukça görünür.",
        .de: "Ordner und Mindestgröße wählen, dann Scannen. Ergebnisse erscheinen laufend.",
        .es: "Elige una carpeta y un tamaño mínimo, y pulsa Analizar. Los resultados aparecen sobre la marcha.",
        .fr: "Choisissez un dossier et une taille minimale, puis lancez l'analyse. Les résultats s'affichent au fil de l'eau.",
        .zh: "选择文件夹和最小体积后点击扫描，结果会边找边显示。",
    ])

    static func scannedFiles(_ visited: Int, _ matches: Int) -> T {
        T([
            .en: "Scanned \(visited) files — \(matches) matches",
            .uz: "\(visited) ta fayl ko'rildi — \(matches) ta topildi",
            .ru: "Просмотрено \(visited) файлов — найдено \(matches)",
            .tr: "\(visited) dosya tarandı — \(matches) eşleşme",
            .de: "\(visited) Dateien geprüft — \(matches) Treffer",
            .es: "\(visited) archivos revisados — \(matches) coincidencias",
            .fr: "\(visited) fichiers parcourus — \(matches) résultats",
            .zh: "已检查 \(visited) 个文件 — 匹配 \(matches) 个",
        ])
    }

    static func walking(_ folder: String) -> T {
        T([
            .en: "Walking \(folder)…", .uz: "\(folder) kezilmoqda…",
            .ru: "Обход \(folder)…", .tr: "\(folder) taranıyor…",
            .de: "\(folder) wird durchsucht…", .es: "Recorriendo \(folder)…",
            .fr: "Parcours de \(folder)…", .zh: "正在遍历 \(folder)…",
        ])
    }

    static func noFilesAbove(_ mb: Int) -> T {
        T([
            .en: "No files above \(mb) MB", .uz: "\(mb) MB dan katta fayl yo'q",
            .ru: "Нет файлов больше \(mb) МБ", .tr: "\(mb) MB'tan büyük dosya yok",
            .de: "Keine Dateien über \(mb) MB", .es: "No hay archivos de más de \(mb) MB",
            .fr: "Aucun fichier de plus de \(mb) Mo", .zh: "没有大于 \(mb) MB 的文件",
        ])
    }

    static func selectedSize(_ count: Int, _ size: String) -> T {
        T([
            .en: "\(count) selected · \(size)", .uz: "\(count) ta tanlandi · \(size)",
            .ru: "Выбрано \(count) · \(size)", .tr: "\(count) seçildi · \(size)",
            .de: "\(count) ausgewählt · \(size)", .es: "\(count) seleccionados · \(size)",
            .fr: "\(count) sélectionnés · \(size)", .zh: "已选 \(count) 项 · \(size)",
        ])
    }

    static func confirmTrashFiles(_ count: Int, _ size: String) -> T {
        T([
            .en: "Move \(count) files (\(size)) to the Trash?",
            .uz: "\(count) ta fayl (\(size)) Savatga tashlansinmi?",
            .ru: "Переместить \(count) файлов (\(size)) в Корзину?",
            .tr: "\(count) dosya (\(size)) Çöp Kutusu'na taşınsın mı?",
            .de: "\(count) Dateien (\(size)) in den Papierkorb legen?",
            .es: "¿Mover \(count) archivos (\(size)) a la Papelera?",
            .fr: "Mettre \(count) fichiers (\(size)) à la Corbeille ?",
            .zh: "将 \(count) 个文件（\(size)）移到废纸篓？",
        ])
    }

    // Projects
    static let projectsIntro = T([
        .en: "Dependencies and build output you can delete — they come back with one command.",
        .uz: "O'chirsa bo'ladigan kutubxona va yig'ish fayllari — bitta buyruq bilan qaytadi.",
        .ru: "Зависимости и файлы сборки, которые можно удалить — вернутся одной командой.",
        .tr: "Silebileceğiniz bağımlılıklar ve derleme çıktıları — tek komutla geri gelir.",
        .de: "Abhängigkeiten und Build-Ausgaben, die Sie löschen können — ein Befehl holt sie zurück.",
        .es: "Dependencias y resultados de compilación que puedes borrar: vuelven con un comando.",
        .fr: "Dépendances et fichiers de build supprimables — une commande suffit à les rétablir.",
        .zh: "可删除的依赖和构建产物 — 一条命令即可恢复。",
    ])
    static let staleOnly = T([
        .en: "Only untouched for 3 months", .uz: "Faqat 3 oy tegilmaganlari",
        .ru: "Только нетронутые 3 месяца", .tr: "Yalnızca 3 aydır dokunulmayanlar",
        .de: "Nur seit 3 Monaten unberührt", .es: "Solo sin tocar desde hace 3 meses",
        .fr: "Seulement inchangés depuis 3 mois", .zh: "仅 3 个月未动过的",
    ])
    static let selectStale = T([
        .en: "Select stale", .uz: "Eskilarini tanlash", .ru: "Выбрать старые",
        .tr: "Eskileri seç", .de: "Alte auswählen", .es: "Seleccionar antiguos",
        .fr: "Sélectionner les anciens", .zh: "选择陈旧项",
    ])
    static let noProjects = T([
        .en: "No projects found here", .uz: "Bu yerda loyiha topilmadi",
        .ru: "Здесь проектов не найдено", .tr: "Burada proje bulunamadı",
        .de: "Hier wurden keine Projekte gefunden", .es: "No se encontraron proyectos aquí",
        .fr: "Aucun projet trouvé ici", .zh: "这里没有找到项目",
    ])
    static let projectsHint = T([
        .en: "Pick a folder that holds your projects and press Scan. Only folders that sit next to "
            + "a package.json, Cargo.toml, Podfile and the like are offered.",
        .uz: "Loyihalaringiz turgan papkani tanlab, Tekshirish ni bosing. Faqat package.json, "
            + "Cargo.toml, Podfile kabi fayllar yonida turgan papkalar ko'rsatiladi.",
        .ru: "Выберите папку с проектами и нажмите Проверить. Показываются только папки, рядом с "
            + "которыми лежит package.json, Cargo.toml, Podfile и подобные файлы.",
        .tr: "Projelerinizin bulunduğu klasörü seçip Tara'ya basın. Yalnızca yanında package.json, "
            + "Cargo.toml, Podfile gibi dosyalar olan klasörler listelenir.",
        .de: "Wählen Sie den Ordner mit Ihren Projekten und starten Sie den Scan. Angeboten werden nur "
            + "Ordner, neben denen eine package.json, Cargo.toml, Podfile o. Ä. liegt.",
        .es: "Elige la carpeta con tus proyectos y pulsa Analizar. Solo se ofrecen carpetas junto a "
            + "un package.json, Cargo.toml, Podfile o similar.",
        .fr: "Choisissez le dossier de vos projets puis lancez l'analyse. Seuls les dossiers voisins "
            + "d'un package.json, Cargo.toml, Podfile ou équivalent sont proposés.",
        .zh: "选择存放项目的文件夹后点击扫描。只会列出旁边有 package.json、Cargo.toml、Podfile 等文件的目录。",
    ])
    static let kindNodeModules = T([
        .en: "dependencies", .uz: "kutubxonalar", .ru: "зависимости", .tr: "bağımlılıklar",
        .de: "Abhängigkeiten", .es: "dependencias", .fr: "dépendances", .zh: "依赖包",
    ])
    static let kindBuildOutput = T([
        .en: "build output", .uz: "yig'ish natijasi", .ru: "результат сборки",
        .tr: "derleme çıktısı", .de: "Build-Ausgabe", .es: "salida de compilación",
        .fr: "sortie de build", .zh: "构建产物",
    ])
    static let kindPods = T([
        .en: "CocoaPods", .uz: "CocoaPods", .ru: "CocoaPods", .tr: "CocoaPods",
        .de: "CocoaPods", .es: "CocoaPods", .fr: "CocoaPods", .zh: "CocoaPods",
    ])
    static let kindGradle = T([
        .en: "Gradle cache", .uz: "Gradle keshi", .ru: "кэш Gradle", .tr: "Gradle önbelleği",
        .de: "Gradle-Cache", .es: "caché de Gradle", .fr: "cache Gradle", .zh: "Gradle 缓存",
    ])
    static let kindTarget = T([
        .en: "build target", .uz: "build target", .ru: "каталог сборки",
        .tr: "derleme hedefi", .de: "Build-Target", .es: "destino de compilación",
        .fr: "cible de build", .zh: "构建目录",
    ])
    static let kindPython = T([
        .en: "Python files", .uz: "Python fayllari", .ru: "файлы Python",
        .tr: "Python dosyaları", .de: "Python-Dateien", .es: "archivos de Python",
        .fr: "fichiers Python", .zh: "Python 文件",
    ])
    static let kindVendor = T([
        .en: "vendor", .uz: "vendor", .ru: "vendor", .tr: "vendor",
        .de: "vendor", .es: "vendor", .fr: "vendor", .zh: "vendor 目录",
    ])
    static let kindDerivedData = T([
        .en: "Xcode DerivedData", .uz: "Xcode DerivedData", .ru: "Xcode DerivedData",
        .tr: "Xcode DerivedData", .de: "Xcode DerivedData", .es: "Xcode DerivedData",
        .fr: "Xcode DerivedData", .zh: "Xcode DerivedData",
    ])

    static func restoreWith(_ command: String) -> T {
        T([
            .en: "comes back with `\(command)`", .uz: "`\(command)` bilan qaytadi",
            .ru: "вернётся по `\(command)`", .tr: "`\(command)` ile geri gelir",
            .de: "kommt mit `\(command)` zurück", .es: "vuelve con `\(command)`",
            .fr: "revient avec `\(command)`", .zh: "用 `\(command)` 可恢复",
        ])
    }

    static func projectsFound(_ projects: Int, _ size: String) -> T {
        T([
            .en: "\(projects) projects · \(size) reclaimable",
            .uz: "\(projects) ta loyiha · \(size) bo'shatish mumkin",
            .ru: "\(projects) проектов · можно освободить \(size)",
            .tr: "\(projects) proje · \(size) boşaltılabilir",
            .de: "\(projects) Projekte · \(size) freigebbar",
            .es: "\(projects) proyectos · \(size) recuperables",
            .fr: "\(projects) projets · \(size) récupérables",
            .zh: "\(projects) 个项目 · 可释放 \(size)",
        ])
    }

    static func lastTouched(_ age: String) -> T {
        T([
            .en: "last touched \(age)", .uz: "oxirgi marta \(age)",
            .ru: "последнее изменение \(age)", .tr: "son dokunuş \(age)",
            .de: "zuletzt bearbeitet \(age)", .es: "última modificación \(age)",
            .fr: "dernière modification \(age)", .zh: "最后修改 \(age)",
        ])
    }

    // Disk map
    static let diskMapIntro = T([
        .en: "See where the space actually went — every folder drawn to scale.",
        .uz: "Joy qayerga ketganini ko'rsatadi — har bir papka hajmiga yarasha chizilgan.",
        .ru: "Показывает, куда ушло место — каждая папка нарисована по размеру.",
        .tr: "Alanın nereye gittiğini gösterir — her klasör boyutuna göre çizilir.",
        .de: "Zeigt, wohin der Speicher ging — jeder Ordner maßstabsgetreu gezeichnet.",
        .es: "Muestra a dónde fue el espacio: cada carpeta dibujada a escala.",
        .fr: "Montre où est passé l'espace — chaque dossier dessiné à l'échelle.",
        .zh: "看清空间去了哪里 — 每个文件夹按体积绘制。",
    ])
    static let diskMapHint = T([
        .en: "Pick a folder and press Scan. One pass builds the whole tree, then clicking a "
            + "bubble opens it instantly.",
        .uz: "Papkani tanlab, Tekshirish ni bosing. Bitta o'tishda butun daraxt tuziladi, "
            + "keyin pufakni bosishingiz bilan darrov ochiladi.",
        .ru: "Выберите папку и нажмите Проверить. Дерево строится за один проход, потом "
            + "клик по кружку открывает его мгновенно.",
        .tr: "Bir klasör seçip Tara'ya basın. Ağaç tek geçişte kurulur, sonra bir baloncuğa "
            + "tıklamanız yeterli.",
        .de: "Ordner wählen und Scannen drücken. Der Baum entsteht in einem Durchgang, danach "
            + "öffnet ein Klick auf eine Blase sie sofort.",
        .es: "Elige una carpeta y pulsa Analizar. El árbol se construye en una pasada y luego "
            + "cada burbuja se abre al instante.",
        .fr: "Choisissez un dossier et lancez l'analyse. L'arbre se construit en une passe, puis "
            + "un clic sur une bulle l'ouvre instantanément.",
        .zh: "选择文件夹后点击扫描。一次遍历即可建好整棵树，之后点击气泡会立即展开。",
    ])
    static let up = T([
        .en: "Up", .uz: "Yuqoriga", .ru: "Вверх", .tr: "Yukarı",
        .de: "Nach oben", .es: "Arriba", .fr: "Remonter", .zh: "上一级",
    ])
    static let emptyFolder = T([
        .en: "Nothing big enough to draw here", .uz: "Bu yerda chizishga arziydigan narsa yo'q",
        .ru: "Здесь нечего показывать", .tr: "Burada çizmeye değer bir şey yok",
        .de: "Hier ist nichts groß genug zum Zeichnen", .es: "Aquí no hay nada que dibujar",
        .fr: "Rien d'assez grand à afficher ici", .zh: "这里没有足够大的内容可显示",
    ])

    static func scanningTree(_ files: Int, _ size: String) -> T {
        T([
            .en: "\(files) files · \(size) measured", .uz: "\(files) ta fayl · \(size) o'lchandi",
            .ru: "\(files) файлов · измерено \(size)", .tr: "\(files) dosya · \(size) ölçüldü",
            .de: "\(files) Dateien · \(size) gemessen", .es: "\(files) archivos · \(size) medidos",
            .fr: "\(files) fichiers · \(size) mesurés", .zh: "\(files) 个文件 · 已测量 \(size)",
        ])
    }

    // Apps
    static let searchApps = T([
        .en: "Search apps", .uz: "Ilova qidirish", .ru: "Поиск программ",
        .tr: "Uygulama ara", .de: "Apps suchen", .es: "Buscar apps",
        .fr: "Rechercher une app", .zh: "搜索应用",
    ])
    static let appsIntro = T([
        .en: "Everything installed in /Applications and your home folder.",
        .uz: "/Applications va uy papkangizga o'rnatilgan barcha ilovalar.",
        .ru: "Всё, что установлено в /Applications и в домашней папке.",
        .tr: "/Applications ve ana klasörünüzde yüklü olan her şey.",
        .de: "Alles, was in /Applications und Ihrem Benutzerordner installiert ist.",
        .es: "Todo lo instalado en /Applications y en tu carpeta personal.",
        .fr: "Tout ce qui est installé dans /Applications et votre dossier personnel.",
        .zh: "/Applications 和个人文件夹中安装的所有应用。",
    ])
    static let hiddenAppsIntro = T([
        .en: "Menu-bar helpers and apps installed outside the normal places. "
            + "They have no Dock icon, so they are easy to forget.",
        .uz: "Menyu satridagi yordamchilar va odatdagi joydan tashqarida o'rnatilgan ilovalar. "
            + "Ular Dock'da ko'rinmaydi, shuning uchun esdan chiqadi.",
        .ru: "Помощники в строке меню и программы, установленные не в обычных местах. "
            + "У них нет значка в Dock, поэтому о них легко забыть.",
        .tr: "Menü çubuğundaki yardımcılar ve alışılmadık yerlere kurulmuş uygulamalar. "
            + "Dock'ta simgeleri olmadığı için kolayca unutulurlar.",
        .de: "Menüleisten-Helfer und Apps außerhalb der üblichen Orte. "
            + "Sie haben kein Dock-Symbol und geraten leicht in Vergessenheit.",
        .es: "Ayudantes de la barra de menús y apps instaladas fuera de los sitios habituales. "
            + "No tienen icono en el Dock, así que es fácil olvidarlas.",
        .fr: "Utilitaires de la barre des menus et apps installées hors des emplacements habituels. "
            + "Sans icône dans le Dock, on les oublie facilement.",
        .zh: "菜单栏助手，以及安装在非常规位置的应用。它们没有程序坞图标，很容易被遗忘。",
    ])
    static let pickAppTitle = T([
        .en: "Remove an app completely", .uz: "Ilovani butunlay o'chirish",
        .ru: "Полностью удалить программу", .tr: "Uygulamayı tamamen kaldır",
        .de: "App vollständig entfernen", .es: "Eliminar una app por completo",
        .fr: "Supprimer une app entièrement", .zh: "彻底卸载应用",
    ])
    static let pickAppBody = T([
        .en: "Pick an app to see the caches, preferences and containers it left in your Library — "
            + "then remove all of it in one go.",
        .uz: "Ilovani tanlang — u Library'da qoldirgan kesh, sozlama va konteynerlarini ko'rasiz, "
            + "hammasini birdaniga o'chirasiz.",
        .ru: "Выберите программу — увидите кэш, настройки и контейнеры, которые она оставила в "
            + "Library, и удалите всё разом.",
        .tr: "Bir uygulama seçin — Library'de bıraktığı önbellek, ayar ve konteynerleri görün, "
            + "hepsini tek seferde silin.",
        .de: "Wählen Sie eine App und sehen Sie Caches, Einstellungen und Container, die sie in "
            + "der Library hinterlassen hat — alles auf einmal entfernbar.",
        .es: "Elige una app para ver las cachés, preferencias y contenedores que dejó en Library "
            + "y bórralo todo de una vez.",
        .fr: "Choisissez une app pour voir les caches, préférences et conteneurs laissés dans "
            + "Library — puis supprimez le tout d'un coup.",
        .zh: "选择一个应用，即可看到它遗留在 Library 中的缓存、偏好设置和容器，并一次性全部清除。",
    ])
    static let leftovers = T([
        .en: "Support files left behind", .uz: "Qolib ketgan yordamchi fayllar",
        .ru: "Оставшиеся служебные файлы", .tr: "Geride kalan destek dosyaları",
        .de: "Zurückgelassene Hilfsdateien", .es: "Archivos de soporte que quedaron",
        .fr: "Fichiers de support laissés", .zh: "遗留的支持文件",
    ])
    static let noLeftovers = T([
        .en: "No leftover files matched this app.", .uz: "Bu ilovadan qolgan fayl topilmadi.",
        .ru: "Остаточных файлов этой программы не найдено.",
        .tr: "Bu uygulamadan kalan dosya bulunamadı.",
        .de: "Keine Restdateien zu dieser App gefunden.",
        .es: "No se encontraron archivos sobrantes de esta app.",
        .fr: "Aucun fichier résiduel trouvé pour cette app.",
        .zh: "未找到该应用的遗留文件。",
    ])
    static let uninstall = T([
        .en: "Uninstall", .uz: "O'chirish", .ru: "Удалить", .tr: "Kaldır",
        .de: "Deinstallieren", .es: "Desinstalar", .fr: "Désinstaller", .zh: "卸载",
    ])
    static let uninstallNote = T([
        .en: "Quit the app first. Everything goes to the Trash and can be restored.",
        .uz: "Avval ilovani yoping. Hammasi Savatga tushadi va qaytarib olinadi.",
        .ru: "Сначала закройте программу. Всё попадёт в Корзину и может быть возвращено.",
        .tr: "Önce uygulamayı kapatın. Her şey Çöp Kutusu'na gider ve geri alınabilir.",
        .de: "Beenden Sie die App zuerst. Alles landet im Papierkorb und ist wiederherstellbar.",
        .es: "Cierra la app primero. Todo va a la Papelera y se puede restaurar.",
        .fr: "Quittez l'app d'abord. Tout va à la Corbeille et reste récupérable.",
        .zh: "请先退出该应用。所有内容都会进入废纸篓，可以还原。",
    ])
    static let systemAppNote = T([
        .en: "This is a macOS system app and cannot be removed.",
        .uz: "Bu macOS tizim ilovasi — uni o'chirib bo'lmaydi.",
        .ru: "Это системная программа macOS, её нельзя удалить.",
        .tr: "Bu bir macOS sistem uygulamasıdır, kaldırılamaz.",
        .de: "Das ist eine macOS-Systemapp und kann nicht entfernt werden.",
        .es: "Es una app del sistema de macOS y no se puede eliminar.",
        .fr: "C'est une app système de macOS, elle ne peut pas être supprimée.",
        .zh: "这是 macOS 系统应用，无法卸载。",
    ])
    static let badgeMenuBar = T([
        .en: "Menu bar", .uz: "Menyu satri", .ru: "Строка меню", .tr: "Menü çubuğu",
        .de: "Menüleiste", .es: "Barra de menús", .fr: "Barre des menus", .zh: "菜单栏",
    ])
    static let badgeUnusualPlace = T([
        .en: "Unusual location", .uz: "G'ayrioddiy joy", .ru: "Необычное место",
        .tr: "Alışılmadık konum", .de: "Ungewöhnlicher Ort", .es: "Ubicación inusual",
        .fr: "Emplacement inhabituel", .zh: "非常规位置",
    ])
    static let badgeRunning = T([
        .en: "Running", .uz: "Ishlayapti", .ru: "Запущено", .tr: "Çalışıyor",
        .de: "Läuft", .es: "En ejecución", .fr: "En cours", .zh: "运行中",
    ])
    static let badgeSystem = T([
        .en: "System", .uz: "Tizim", .ru: "Система", .tr: "Sistem",
        .de: "System", .es: "Sistema", .fr: "Système", .zh: "系统",
    ])

    static func foundCount(_ count: Int) -> T {
        T([
            .en: "\(count) found", .uz: "\(count) ta topildi", .ru: "найдено \(count)",
            .tr: "\(count) bulundu", .de: "\(count) gefunden", .es: "\(count) encontrados",
            .fr: "\(count) trouvés", .zh: "找到 \(count) 项",
        ])
    }

    static func totalToRemove(_ size: String) -> T {
        T([
            .en: "Total to remove: \(size)", .uz: "Jami o'chiriladi: \(size)",
            .ru: "Всего к удалению: \(size)", .tr: "Toplam silinecek: \(size)",
            .de: "Insgesamt zu entfernen: \(size)", .es: "Total a eliminar: \(size)",
            .fr: "Total à supprimer : \(size)", .zh: "将删除共计：\(size)",
        ])
    }

    static func confirmUninstall(_ name: String, _ count: Int) -> T {
        T([
            .en: "Move \(name) and \(count) support files to the Trash?",
            .uz: "\(name) va \(count) ta yordamchi fayl Savatga tashlansinmi?",
            .ru: "Переместить \(name) и \(count) служебных файлов в Корзину?",
            .tr: "\(name) ve \(count) destek dosyası Çöp Kutusu'na taşınsın mı?",
            .de: "\(name) und \(count) Hilfsdateien in den Papierkorb legen?",
            .es: "¿Mover \(name) y \(count) archivos de soporte a la Papelera?",
            .fr: "Mettre \(name) et \(count) fichiers de support à la Corbeille ?",
            .zh: "将 \(name) 及 \(count) 个支持文件移到废纸篓？",
        ])
    }

    static func appsFound(_ count: Int) -> T {
        T([
            .en: "\(count) apps", .uz: "\(count) ta ilova", .ru: "\(count) программ",
            .tr: "\(count) uygulama", .de: "\(count) Apps", .es: "\(count) apps",
            .fr: "\(count) apps", .zh: "\(count) 个应用",
        ])
    }

    // Processes
    static let processesIntro = T([
        .en: "Apps and helpers running right now, heaviest first.",
        .uz: "Hozir ishlab turgan ilova va yordamchilar — og'irlaridan boshlab.",
        .ru: "Программы и помощники, запущенные сейчас — начиная с самых тяжёлых.",
        .tr: "Şu anda çalışan uygulama ve yardımcılar — en ağırdan başlayarak.",
        .de: "Aktuell laufende Apps und Helfer, die schwersten zuerst.",
        .es: "Apps y ayudantes en ejecución, empezando por los más pesados.",
        .fr: "Apps et utilitaires en cours, les plus lourds d'abord.",
        .zh: "当前运行的应用和助手，占用最多的排在前面。",
    ])
    static let onlyBackground = T([
        .en: "Only background ones", .uz: "Faqat fondagilar", .ru: "Только фоновые",
        .tr: "Yalnızca arka plandakiler", .de: "Nur Hintergrundprozesse",
        .es: "Solo los de segundo plano", .fr: "Seulement ceux en arrière-plan",
        .zh: "仅后台程序",
    ])
    static let quit = T([
        .en: "Quit", .uz: "Yopish", .ru: "Завершить", .tr: "Kapat",
        .de: "Beenden", .es: "Salir", .fr: "Quitter", .zh: "退出",
    ])
    static let memory = T([
        .en: "Memory", .uz: "Xotira", .ru: "Память", .tr: "Bellek",
        .de: "Speicher", .es: "Memoria", .fr: "Mémoire", .zh: "内存",
    ])
    static let noDockIcon = T([
        .en: "No Dock icon", .uz: "Dock'da yo'q", .ru: "Нет значка в Dock",
        .tr: "Dock'ta simgesi yok", .de: "Kein Dock-Symbol", .es: "Sin icono en el Dock",
        .fr: "Pas d'icône dans le Dock", .zh: "无程序坞图标",
    ])
    static let quitNote = T([
        .en: "Quitting asks the app to close normally — unsaved work is kept.",
        .uz: "Yopish so'rovi ilovaga odatdagidek yopilishni aytadi — saqlanmagan ish yo'qolmaydi.",
        .ru: "Завершение просит программу закрыться штатно — несохранённая работа не пропадёт.",
        .tr: "Kapatma isteği uygulamadan normal şekilde kapanmasını ister — kaydedilmemiş iş kaybolmaz.",
        .de: "Beenden bittet die App, sich normal zu schließen — ungesicherte Arbeit bleibt erhalten.",
        .es: "Salir pide a la app que se cierre con normalidad: no se pierde el trabajo sin guardar.",
        .fr: "Quitter demande à l'app de se fermer normalement — le travail non enregistré est conservé.",
        .zh: "退出会请求应用正常关闭，未保存的工作不会丢失。",
    ])

    static func confirmQuit(_ name: String) -> T {
        T([
            .en: "Quit \(name)?", .uz: "\(name) yopilsinmi?", .ru: "Завершить \(name)?",
            .tr: "\(name) kapatılsın mı?", .de: "\(name) beenden?", .es: "¿Salir de \(name)?",
            .fr: "Quitter \(name) ?", .zh: "退出 \(name)？",
        ])
    }

    static func processSummary(_ count: Int, _ memory: String) -> T {
        T([
            .en: "\(count) processes · \(memory)", .uz: "\(count) ta jarayon · \(memory)",
            .ru: "\(count) процессов · \(memory)", .tr: "\(count) işlem · \(memory)",
            .de: "\(count) Prozesse · \(memory)", .es: "\(count) procesos · \(memory)",
            .fr: "\(count) processus · \(memory)", .zh: "\(count) 个进程 · \(memory)",
        ])
    }

    // Services
    static let servicesIntro = T([
        .en: "Programs macOS starts on its own — at login or in the background.",
        .uz: "macOS o'zi ishga tushiradigan dasturlar — tizimga kirganda yoki fonda.",
        .ru: "Программы, которые macOS запускает сама — при входе или в фоне.",
        .tr: "macOS'in kendiliğinden başlattığı programlar — girişte veya arka planda.",
        .de: "Programme, die macOS selbst startet — beim Anmelden oder im Hintergrund.",
        .es: "Programas que macOS inicia por su cuenta: al iniciar sesión o en segundo plano.",
        .fr: "Programmes que macOS lance de lui-même — à la connexion ou en arrière-plan.",
        .zh: "macOS 自动启动的程序 — 登录时或在后台运行。",
    ])
    static let showAppleServices = T([
        .en: "Show Apple services", .uz: "Apple xizmatlarini ko'rsatish",
        .ru: "Показать службы Apple", .tr: "Apple servislerini göster",
        .de: "Apple-Dienste anzeigen", .es: "Mostrar servicios de Apple",
        .fr: "Afficher les services Apple", .zh: "显示 Apple 服务",
    ])
    static let loaded = T([
        .en: "Active", .uz: "Faol", .ru: "Активно", .tr: "Etkin",
        .de: "Aktiv", .es: "Activo", .fr: "Actif", .zh: "已启用",
    ])
    static let notLoaded = T([
        .en: "Inactive", .uz: "Faol emas", .ru: "Неактивно", .tr: "Etkin değil",
        .de: "Inaktiv", .es: "Inactivo", .fr: "Inactif", .zh: "未启用",
    ])
    static let startsAtLogin = T([
        .en: "Starts at login", .uz: "Kirishda ishga tushadi", .ru: "Запускается при входе",
        .tr: "Girişte başlar", .de: "Startet bei der Anmeldung", .es: "Se inicia al iniciar sesión",
        .fr: "Démarre à la connexion", .zh: "登录时启动",
    ])
    static let scopeUser = T([
        .en: "Yours", .uz: "Sizniki", .ru: "Ваше", .tr: "Sizin",
        .de: "Ihres", .es: "Tuyo", .fr: "Le vôtre", .zh: "你的",
    ])
    static let scopeAdmin = T([
        .en: "All users", .uz: "Barcha foydalanuvchilar", .ru: "Все пользователи",
        .tr: "Tüm kullanıcılar", .de: "Alle Benutzer", .es: "Todos los usuarios",
        .fr: "Tous les utilisateurs", .zh: "所有用户",
    ])
    static let scopeSystem = T([
        .en: "macOS", .uz: "macOS", .ru: "macOS", .tr: "macOS",
        .de: "macOS", .es: "macOS", .fr: "macOS", .zh: "macOS",
    ])
    static let disableAndTrash = T([
        .en: "Turn off & remove", .uz: "O'chirib, Savatga", .ru: "Выключить и удалить",
        .tr: "Kapat ve kaldır", .de: "Ausschalten & entfernen", .es: "Desactivar y eliminar",
        .fr: "Désactiver et supprimer", .zh: "关闭并移除",
    ])
    static let readOnlyService = T([
        .en: "Needs an administrator — MacBroom will only show you where it lives.",
        .uz: "Administrator huquqi kerak — MacBroom faqat joyini ko'rsatadi.",
        .ru: "Нужны права администратора — MacBroom только покажет, где это лежит.",
        .tr: "Yönetici yetkisi gerekir — MacBroom yalnızca yerini gösterir.",
        .de: "Benötigt Administratorrechte — MacBroom zeigt nur den Speicherort.",
        .es: "Requiere permisos de administrador: MacBroom solo te mostrará dónde está.",
        .fr: "Nécessite un administrateur — MacBroom se contente d'indiquer l'emplacement.",
        .zh: "需要管理员权限 — MacBroom 只会显示它所在的位置。",
    ])
    static let serviceNote = T([
        .en: "The service is stopped and its file goes to the Trash. Put it back to undo.",
        .uz: "Xizmat to'xtatiladi va fayli Savatga tushadi. Qaytarsangiz tiklanadi.",
        .ru: "Служба останавливается, а её файл уходит в Корзину. Верните файл, чтобы отменить.",
        .tr: "Servis durdurulur ve dosyası Çöp Kutusu'na gider. Geri koyarsanız eski hâline döner.",
        .de: "Der Dienst wird gestoppt und seine Datei landet im Papierkorb. Zurücklegen macht es rückgängig.",
        .es: "El servicio se detiene y su archivo va a la Papelera. Devuélvelo para deshacer.",
        .fr: "Le service est arrêté et son fichier va à la Corbeille. Remettez-le pour annuler.",
        .zh: "服务会被停止，其配置文件移到废纸篓。放回即可撤销。",
    ])
    static let noServices = T([
        .en: "No services here", .uz: "Bu yerda xizmat yo'q", .ru: "Здесь нет служб",
        .tr: "Burada servis yok", .de: "Hier gibt es keine Dienste", .es: "Aquí no hay servicios",
        .fr: "Aucun service ici", .zh: "这里没有服务",
    ])

    static func confirmDisable(_ label: String) -> T {
        T([
            .en: "Turn off \(label)?", .uz: "\(label) o'chirilsinmi?",
            .ru: "Выключить \(label)?", .tr: "\(label) kapatılsın mı?",
            .de: "\(label) ausschalten?", .es: "¿Desactivar \(label)?",
            .fr: "Désactiver \(label) ?", .zh: "关闭 \(label)？",
        ])
    }

    static func servicesSummary(_ total: Int, _ active: Int) -> T {
        T([
            .en: "\(total) services · \(active) active",
            .uz: "\(total) ta xizmat · \(active) tasi faol",
            .ru: "\(total) служб · активно \(active)",
            .tr: "\(total) servis · \(active) etkin",
            .de: "\(total) Dienste · \(active) aktiv",
            .es: "\(total) servicios · \(active) activos",
            .fr: "\(total) services · \(active) actifs",
            .zh: "\(total) 项服务 · \(active) 项启用",
        ])
    }

    // Relative dates
    static let ageToday = T([
        .en: "today", .uz: "bugun", .ru: "сегодня", .tr: "bugün",
        .de: "heute", .es: "hoy", .fr: "aujourd'hui", .zh: "今天",
    ])

    static func ageDays(_ n: Int) -> T {
        T([
            .en: "\(n)d ago", .uz: "\(n) kun oldin", .ru: "\(n) дн. назад",
            .tr: "\(n) gün önce", .de: "vor \(n) T.", .es: "hace \(n) d",
            .fr: "il y a \(n) j", .zh: "\(n) 天前",
        ])
    }

    static func ageMonths(_ n: Int) -> T {
        T([
            .en: "\(n)mo ago", .uz: "\(n) oy oldin", .ru: "\(n) мес. назад",
            .tr: "\(n) ay önce", .de: "vor \(n) Mon.", .es: "hace \(n) meses",
            .fr: "il y a \(n) mois", .zh: "\(n) 个月前",
        ])
    }

    static func ageYears(_ n: Int) -> T {
        T([
            .en: "\(n)y ago", .uz: "\(n) yil oldin", .ru: "\(n) г. назад",
            .tr: "\(n) yıl önce", .de: "vor \(n) J.", .es: "hace \(n) años",
            .fr: "il y a \(n) ans", .zh: "\(n) 年前",
        ])
    }

    // CLI report
    static let cliHeader = T([
        .en: "MacBroom — scan report (nothing was removed)",
        .uz: "MacBroom — hisobot (hech narsa o'chirilmadi)",
        .ru: "MacBroom — отчёт (ничего не удалено)",
        .tr: "MacBroom — rapor (hiçbir şey silinmedi)",
        .de: "MacBroom — Bericht (nichts wurde entfernt)",
        .es: "MacBroom — informe (no se eliminó nada)",
        .fr: "MacBroom — rapport (rien n'a été supprimé)",
        .zh: "MacBroom — 扫描报告（未删除任何内容）",
    ])

    static func cliDisk(_ total: String, _ used: String, _ free: String) -> T {
        T([
            .en: "Disk: \(used) used of \(total), \(free) free",
            .uz: "Disk: \(total) dan \(used) band, \(free) bo'sh",
            .ru: "Диск: занято \(used) из \(total), свободно \(free)",
            .tr: "Disk: \(total) alanın \(used) dolu, \(free) boş",
            .de: "Volume: \(used) von \(total) belegt, \(free) frei",
            .es: "Disco: \(used) usados de \(total), \(free) libres",
            .fr: "Disque : \(used) utilisés sur \(total), \(free) libres",
            .zh: "磁盘：已用 \(used) / 共 \(total)，可用 \(free)",
        ])
    }

    static func cliPurgeable(_ size: String) -> T {
        T([
            .en: "A further \(size) is purgeable by macOS on demand",
            .uz: "Yana \(size) ni macOS kerak bo'lganda o'zi bo'shatadi",
            .ru: "Ещё \(size) macOS может освободить при необходимости",
            .tr: "Ayrıca \(size) macOS tarafından gerektiğinde boşaltılabilir",
            .de: "Weitere \(size) kann macOS bei Bedarf freigeben",
            .es: "Otros \(size) los puede liberar macOS si hace falta",
            .fr: "\(size) de plus peuvent être libérés par macOS au besoin",
            .zh: "另有 \(size) 可由 macOS 按需释放",
        ])
    }

    static func cliReclaimable(_ size: String) -> T {
        T([
            .en: "Reclaimable: \(size)", .uz: "Bo'shatish mumkin: \(size)",
            .ru: "Можно освободить: \(size)", .tr: "Boşaltılabilir: \(size)",
            .de: "Freigebbar: \(size)", .es: "Recuperable: \(size)",
            .fr: "Récupérable : \(size)", .zh: "可释放：\(size)",
        ])
    }
}
