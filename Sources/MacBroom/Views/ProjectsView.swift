import AppKit
import SwiftUI

struct ProjectsView: View {
    @ObservedObject var model: ProjectsModel
    @EnvironmentObject private var i18n: I18n
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
            if model.selectedCount > 0 {
                Divider()
                actionBar
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.projects)).font(.system(size: 20, weight: .bold))
                Text(
                    model.hasScanned && !model.groups.isEmpty
                        ? i18n.t(S.projectsFound(model.visible.count, Format.bytes(model.totalSize)))
                        : i18n.t(S.projectsIntro)
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            if model.isScanning {
                Button(i18n.t(S.stop)) { model.cancel() }.buttonStyle(.bordered)
            } else {
                Button(i18n.t(model.hasScanned ? S.rescan : S.scan)) { model.scan() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                chooseFolder()
            } label: {
                Label(model.root.lastPathComponent, systemImage: "folder")
                    .font(.system(size: 11))
            }
            .help(model.root.path)

            Divider().frame(height: 16)

            Toggle(i18n.t(S.staleOnly), isOn: $model.staleOnly)
                .font(.system(size: 11))
                .toggleStyle(.checkbox)

            Spacer()

            if model.isScanning {
                ProgressView(value: model.progress).frame(width: 90)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        if model.visible.isEmpty {
            if model.isScanning {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(i18n.t(S.walking(model.root.lastPathComponent)))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    symbol: "folder.badge.gearshape",
                    title: i18n.t(model.hasScanned ? S.noProjects : S.projects),
                    message: i18n.t(S.projectsHint)
                )
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    FailureList(failures: model.failures).padding(.horizontal, 18)
                    ForEach(model.visible) { group in
                        ProjectCard(group: group, model: model)
                            .padding(.horizontal, 18)
                    }
                }
                .padding(.vertical, 14)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Text(i18n.t(S.selectedSize(model.selectedCount, Format.bytes(model.selectedSize))))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
            Spacer()
            Button(i18n.t(S.selectStale)) { model.selectStale() }.buttonStyle(.link)
            Button(i18n.t(S.none)) { model.deselectAll() }.buttonStyle(.link)
            Button(i18n.t(S.moveToTrash)) { showConfirm = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .confirmationDialog(
            i18n.t(S.confirmTrash(model.selectedCount, Format.bytes(model.selectedSize))),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(i18n.t(S.moveToTrash), role: .destructive) { model.trashSelected() }
            Button(i18n.t(S.cancel), role: .cancel) {}
        } message: {
            Text(i18n.t(S.trashNote))
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = model.root
        if panel.runModal() == .OK, let url = panel.url {
            model.root = url
        }
    }
}

private struct ProjectCard: View {
    let group: ProjectGroup
    @ObservedObject var model: ProjectsModel
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Checkbox(isOn: group.artifacts.allSatisfy(\.isSelected)) {
                    model.toggleProject(group)
                }

                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(Palette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(group.name).font(.system(size: 13, weight: .semibold))
                        if group.isStale {
                            Tag(text: i18n.t(S.adviceLeftover), tint: Palette.warning)
                        }
                    }
                    Text(i18n.t(S.lastTouched(Format.age(group.newestChange))))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(Format.bytes(group.totalSize))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Button {
                    Cleaner.revealInFinder(group.url)
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(group.url.path)
            }
            .padding(12)

            Divider().padding(.leading, 46)

            VStack(spacing: 0) {
                ForEach(group.artifacts) { artifact in
                    HStack(spacing: 10) {
                        Checkbox(isOn: artifact.isSelected) { model.toggle(artifact) }
                        Image(systemName: artifact.kind.symbol)
                            .font(.system(size: 10))
                            .frame(width: 14)
                            .foregroundStyle(.secondary)
                        Text(artifact.url.lastPathComponent)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Text(i18n.t(artifact.kind.label))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(i18n.t(S.restoreWith(artifact.kind.restoreCommand)))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        Text(Format.bytes(artifact.size))
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.leading, 32)
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 6)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }
}
