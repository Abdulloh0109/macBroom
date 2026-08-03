import SwiftUI

enum Feature: String, CaseIterable, Identifiable {
    case system
    case smartScan
    case diskMap
    case systemData
    case growth
    case largeFiles
    case projects
    case apps
    case hiddenApps
    case processes
    case services
    case history

    var id: String { rawValue }

    var title: T {
        switch self {
        case .system: return S.system
        case .smartScan: return S.smartScan
        case .diskMap: return S.diskMap
        case .systemData: return S.systemData
        case .growth: return S.growth
        case .largeFiles: return S.largeFiles
        case .projects: return S.projects
        case .apps: return S.apps
        case .hiddenApps: return S.hiddenApps
        case .processes: return S.processes
        case .services: return S.services
        case .history: return S.history
        }
    }

    var symbol: String {
        switch self {
        case .system: return "gauge.with.dots.needle.67percent"
        case .smartScan: return "sparkles"
        case .diskMap: return "square.grid.3x3.topleft.filled"
        case .systemData: return "questionmark.folder"
        case .growth: return "waveform.path.ecg"
        case .largeFiles: return "externaldrive"
        case .projects: return "folder.badge.gearshape"
        case .apps: return "square.grid.2x2"
        case .hiddenApps: return "eye.slash"
        case .processes: return "bolt.horizontal.circle"
        case .services: return "clock.arrow.circlepath"
        case .history: return "arrow.uturn.backward.circle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var i18n: I18n
    @StateObject private var systemModel = SystemModel()
    @StateObject private var scan = SmartScanModel()
    @StateObject private var largeFiles = LargeFilesModel()
    @StateObject private var diskMap = DiskMapModel()
    @StateObject private var systemData = SystemDataModel()
    @StateObject private var growth = GrowthModel()
    @StateObject private var projects = ProjectsModel()
    @StateObject private var appsModel = AppsModel()
    @StateObject private var processes = ProcessesModel()
    @StateObject private var services = ServicesModel()
    @StateObject private var history = HistoryModel()
    @State private var selection: Feature = .smartScan

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            switch selection {
            case .system: SystemView(model: systemModel)
            case .smartScan: SmartScanView(model: scan)
            case .diskMap: DiskMapView(model: diskMap)
            case .systemData: SystemDataView(model: systemData)
            case .growth: GrowthView(model: growth)
            case .largeFiles: LargeFilesView(model: largeFiles)
            case .projects: ProjectsView(model: projects)
            case .apps: AppsView(model: appsModel, hidden: false)
            case .hiddenApps: AppsView(model: appsModel, hidden: true)
            case .processes: ProcessesView(model: processes)
            case .services: ServicesView(model: services)
            case .history: HistoryView(model: history)
            }
        }
        .navigationTitle("MacBroom")
        // No minWidth here on purpose: a hard minimum makes SwiftUI keep laying the
        // content out at that width and clip the detail column off the right edge
        // when the window is smaller. The window's own minSize (see AppDelegate)
        // is what stops it being shrunk too far.
        .onAppear {
            // Handy for screenshots and smoke tests:
            //   MacBroom --autoscan --tab largeFiles
            let args = CommandLine.arguments
            if let index = args.firstIndex(of: "--tab"), index + 1 < args.count,
                let feature = Feature(rawValue: args[index + 1])
            {
                selection = feature
            }
            if args.contains("--autoscan") {
                switch selection {
                case .smartScan: scan.scan()
                case .largeFiles: largeFiles.scan()
                case .diskMap: diskMap.scan()
                case .projects: projects.scan()
                case .growth: growth.start()
                default: break
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.gradient)
                VStack(alignment: .leading, spacing: 0) {
                    Text("MacBroom").font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(i18n.t(S.appTagline)).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            List(Feature.allCases, selection: $selection) { feature in
                // Two lines: Russian, Spanish and French titles do not fit the
                // sidebar on one line, and the width is user-set and persisted.
                Label(i18n.t(feature.title), systemImage: feature.symbol)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .help(i18n.t(feature.title))
                    .tag(feature)
            }
            .listStyle(.sidebar)

            Divider()

            DiskGauge(disk: scan.disk)
                .padding(.vertical, 14)

            // A real pop-up button rather than a custom Menu: the borderless menu
            // style drops the label text and shows only the indicator.
            Picker(selection: $i18n.language) {
                ForEach(Language.allCases) { language in
                    Text("\(language.flag)  \(language.title)").tag(language)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
            .help(i18n.t(S.language))

            Button {
                scan.refreshDisk()
            } label: {
                Label(i18n.t(S.refresh), systemImage: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 330)
    }
}
