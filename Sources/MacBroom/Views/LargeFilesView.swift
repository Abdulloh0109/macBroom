import AppKit
import SwiftUI

struct LargeFilesView: View {
    @ObservedObject var model: LargeFilesModel
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
                Text(i18n.t(S.largeFiles)).font(.system(size: 20, weight: .bold))
                Text(
                    model.isScanning
                        ? i18n.t(S.scannedFiles(model.scannedCount, model.files.count))
                        : i18n.t(S.largeFilesIntro)
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            if model.isScanning {
                Button(i18n.t(S.stop)) { model.cancel() }.buttonStyle(.bordered)
            } else {
                Button(i18n.t(S.scan)) { model.scan() }.buttonStyle(PrimaryButtonStyle())
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

            Text(i18n.t(S.largerThan))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Slider(value: $model.minimumMB, in: 10...2000, step: 10)
                .frame(width: 160)
            Text("\(Int(model.minimumMB)) MB")
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .frame(width: 56, alignment: .leading)

            Toggle(i18n.t(S.includeLibrary), isOn: $model.includeSystemLibrary)
                .font(.system(size: 11))
                .toggleStyle(.checkbox)

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        if model.files.isEmpty {
            if model.isScanning {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(i18n.t(S.walking(model.root.lastPathComponent)))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    symbol: "externaldrive",
                    title: model.hasScanned
                        ? i18n.t(S.noFilesAbove(Int(model.minimumMB)))
                        : i18n.t(S.nothingScanned),
                    message: i18n.t(S.largeFilesHint)
                )
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    FailureList(failures: model.failures).padding(.horizontal, 18).padding(.top, 8)
                    ForEach(model.files) { file in
                        LargeFileRow(file: file) { model.toggle(file) }
                        Divider().padding(.leading, 46)
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Text(i18n.t(S.selectedSize(model.selectedCount, Format.bytes(model.selectedSize))))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
            Spacer()
            Button(i18n.t(S.none)) { model.deselectAll() }.buttonStyle(.link)
            Button(i18n.t(S.moveToTrash)) { showConfirm = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .confirmationDialog(
            i18n.t(S.confirmTrashFiles(model.selectedCount, Format.bytes(model.selectedSize))),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(i18n.t(S.moveToTrash), role: .destructive) { model.trashSelected() }
            Button(i18n.t(S.cancel), role: .cancel) {}
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

private struct LargeFileRow: View {
    let file: ScanItem
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Checkbox(isOn: file.isSelected, action: toggle)
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.displayName).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                Text(file.url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            Text(Format.age(file.modified))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .trailing)
            Text(Format.bytes(file.size))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(width: 78, alignment: .trailing)
            Button {
                Cleaner.revealInFinder(file.url)
            } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
