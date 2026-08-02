import AppKit
import SwiftUI

struct AppsView: View {
    @ObservedObject var model: AppsModel
    @EnvironmentObject private var i18n: I18n
    /// false → installed apps, true → menu-bar helpers and apps in odd places
    let hidden: Bool

    @State private var showConfirm = false

    private var apps: [AppRecord] { model.visible(hidden: hidden) }

    var body: some View {
        HSplitView {
            list.frame(minWidth: 230, idealWidth: 270, maxWidth: 340)
            detail.frame(minWidth: 360, maxWidth: .infinity)
        }
        .onAppear { model.loadIfNeeded() }
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField(i18n.t(S.searchApps), text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider()

            if model.isLoading && apps.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(i18n.t(S.loading)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(apps) { app in
                            row(app)
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }

            Divider()
            HStack {
                Text(i18n.t(S.appsFound(apps.count)))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isLoading {
                    ProgressView(value: model.progress).frame(width: 60)
                } else {
                    Text(Format.bytes(model.totalSize(hidden: hidden)))
                        .font(.system(size: 10, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }

    private func row(_ app: AppRecord) -> some View {
        HStack(spacing: 9) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                HStack(spacing: 4) {
                    if let version = app.version, !version.isEmpty {
                        Text("v\(version)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if app.isAgent { Tag(text: i18n.t(S.badgeMenuBar), tint: Palette.accent) }
                    if app.location == .elsewhere {
                        Tag(text: i18n.t(S.badgeUnusualPlace), tint: Palette.warning)
                    }
                    if app.location == .system { Tag(text: i18n.t(S.badgeSystem), tint: .gray) }
                    if app.isRunning { Tag(text: i18n.t(S.badgeRunning), tint: .green) }
                }
            }

            Spacer()

            Text(app.size > 0 ? Format.bytes(app.size) : "—")
                .font(.system(size: 10, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            model.selected?.id == app.id
                ? AnyShapeStyle(Palette.accent.opacity(0.18)) : AnyShapeStyle(Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.select(app) }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let app = model.selected, apps.contains(app) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(.system(size: 18, weight: .bold))
                        Text(app.bundleID ?? "—").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(app.url.deletingLastPathComponent().path)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    Spacer()
                    Button {
                        Cleaner.revealInFinder(app.url)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(i18n.t(S.revealInFinder))
                }
                .padding(20)

                Divider()

                HStack {
                    Text(i18n.t(S.leftovers)).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if model.isLoadingLeftovers {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(i18n.t(S.foundCount(model.leftovers.count)))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                if model.leftovers.isEmpty && !model.isLoadingLeftovers {
                    Text(i18n.t(S.noLeftovers))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.leftovers) { leftover in
                                HStack(spacing: 10) {
                                    Checkbox(isOn: leftover.isSelected) { model.toggleLeftover(leftover) }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(leftover.url.lastPathComponent)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(leftover.kind).font(.system(size: 9)).foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Text(Format.bytes(leftover.size))
                                        .font(.system(size: 11, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
                Divider()

                VStack(spacing: 8) {
                    FailureList(failures: model.failures)
                    HStack {
                        if app.isRemovable {
                            Text(i18n.t(S.totalToRemove(Format.bytes(app.size + model.leftoverSize))))
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                        } else {
                            Label(i18n.t(S.systemAppNote), systemImage: "lock")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(i18n.t(S.uninstall)) { showConfirm = true }
                            .buttonStyle(PrimaryButtonStyle(enabled: app.isRemovable))
                            .disabled(!app.isRemovable)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .confirmationDialog(
                i18n.t(S.confirmUninstall(app.name, model.leftovers.filter(\.isSelected).count)),
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button(i18n.t(S.uninstall), role: .destructive) { model.uninstall() }
                Button(i18n.t(S.cancel), role: .cancel) {}
            } message: {
                Text(i18n.t(S.uninstallNote))
            }
        } else {
            EmptyStateView(
                symbol: hidden ? "eye.slash" : "square.grid.2x2",
                title: i18n.t(hidden ? S.hiddenApps : S.pickAppTitle),
                message: i18n.t(hidden ? S.hiddenAppsIntro : S.pickAppBody)
            )
        }
    }
}

struct Tag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
    }
}
