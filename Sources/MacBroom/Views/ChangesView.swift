import AppKit
import SwiftUI

struct ChangesView: View {
    @ObservedObject var model: ChangesModel
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
        }
        .onAppear { model.load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.changes)).font(.system(size: 20, weight: .bold))
                Text(
                    model.isScanning
                        ? i18n.t(S.scanningTree(model.scannedFiles, Format.bytes(model.scannedBytes)))
                        : i18n.t(S.changesIntro)
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            if model.isScanning {
                Button(i18n.t(S.stop)) { model.cancel() }.buttonStyle(.bordered)
            } else {
                Button(i18n.t(S.takeCheckpoint)) { model.take() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button { chooseFolder() } label: {
                Label(model.root.lastPathComponent, systemImage: "folder")
                    .font(.system(size: 11))
            }
            .help(model.root.path)
            .disabled(model.isScanning)

            if model.comparable.count > 1 {
                Divider().frame(height: 16)
                Text(i18n.t(S.compareAgainst)).font(.system(size: 11)).foregroundStyle(.secondary)
                Picker(selection: $model.baseline) {
                    ForEach(model.comparable.dropFirst()) { meta in
                        Text(Format.dateTime(meta.takenAt)).tag(Optional(meta.id))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: 200)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        if model.comparable.isEmpty {
            EmptyStateView(
                symbol: "chart.line.uptrend.xyaxis",
                title: i18n.t(S.changes),
                message: i18n.t(S.changesHint)
            )
        } else if model.comparable.count == 1 {
            EmptyStateView(
                symbol: "clock.badge.checkmark",
                title: i18n.t(S.oneCheckpointTitle),
                message: i18n.t(
                    S.oneCheckpointBody(
                        Format.dateTime(model.comparable[0].takenAt),
                        Format.bytes(model.comparable[0].total)
                    )
                )
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    if let comparison = model.comparison {
                        summaryCard(comparison)
                        if comparison.rows.isEmpty {
                            Text(i18n.t(S.noBigChanges(Format.bytes(DiskComparison.minimumChange))))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 10)
                        } else {
                            ForEach(comparison.rows) { row in
                                ChangeRowView(row: row, largest: largest(comparison))
                            }
                        }
                    } else if model.mismatch {
                        Text(i18n.t(S.checkpointMismatch))
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.warning)
                            .padding(.top, 10)
                    } else {
                        ProgressView().padding(.top, 20)
                    }

                    checkpointList
                    Text(i18n.t(S.changesNote))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
        }
    }

    private func largest(_ comparison: DiskComparison) -> Int64 {
        max(1, comparison.rows.map { abs($0.exclusive) }.max() ?? 1)
    }

    // MARK: - Summary

    private func summaryCard(_ comparison: DiskComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: comparison.netChange > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(comparison.netChange > 0 ? Palette.warning : .green)
                Text(Format.signedBytes(comparison.netChange))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(comparison.netChange > 0 ? Palette.warning : .green)
                Text(i18n.t(S.overSpan(Format.span(comparison.span))))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 22) {
                figure(S.grownTotal, Format.signedBytes(comparison.grown), Palette.warning)
                figure(S.freedTotal, Format.signedBytes(comparison.freed), .green)
                if abs(comparison.scattered) >= 1_048_576 {
                    figure(S.scatteredTotal, Format.signedBytes(comparison.scattered), .secondary)
                }
                Spacer()
            }

            // Two dates and an arrow: nothing here needs translating.
            Text("\(Format.dateTime(comparison.before.takenAt))  →  \(Format.dateTime(comparison.after.takenAt))")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
    }

    private func figure(_ label: T, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(i18n.t(label)).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    // MARK: - Checkpoints

    private var checkpointList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(i18n.t(S.checkpoints))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(model.comparable) { meta in
                HStack(spacing: 8) {
                    Image(systemName: meta.id == model.latest?.id ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(Format.dateTime(meta.takenAt)).font(.system(size: 11)).monospacedDigit()
                    Text(i18n.t(S.checkpointDetail(Format.bytes(meta.total), meta.fileCount)))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                    Spacer()
                    Button {
                        model.delete(meta)
                    } label: {
                        Image(systemName: "trash").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(i18n.t(S.forgetCheckpoint))
                }
                .padding(.vertical, 3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = model.root
        if panel.runModal() == .OK, let url = panel.url {
            model.root = url
            model.load()
        }
    }
}

private struct ChangeRowView: View {
    let row: DiskComparison.Row
    let largest: Int64
    @EnvironmentObject private var i18n: I18n

    private var grew: Bool { row.exclusive > 0 }
    private var fraction: Double { Double(abs(row.exclusive)) / Double(largest) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        switch row.kind {
                        case .appeared: Tag(text: i18n.t(S.badgeNew), tint: Palette.accent)
                        case .vanished: Tag(text: i18n.t(S.badgeGone), tint: .green)
                        case .changed: EmptyView()
                        }
                    }
                    Text(row.relative)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Format.signedBytes(row.exclusive))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(grew ? Palette.warning : .green)
                    Text("\(Format.bytes(row.before)) → \(Format.bytes(row.after))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                Button {
                    Cleaner.revealInFinder(row.url)
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(i18n.t(S.revealInFinder))
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(grew ? Palette.warning : Color.green)
                    .frame(width: max(2, geometry.size.width * fraction))
            }
            .frame(height: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.045)))
    }
}
