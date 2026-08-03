import AppKit
import SwiftUI

struct GrowthView: View {
    @ObservedObject var model: GrowthModel
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
        }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.growth)).font(.system(size: 20, weight: .bold))
                Text(
                    model.isWatching
                        ? i18n.t(S.watchedStats(model.elapsed, model.filesTouched))
                        : i18n.t(S.growthIntro)
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
            }
            Spacer()
            if model.isWatching {
                Button(i18n.t(S.stopWatching)) { model.stop() }.buttonStyle(.bordered)
            } else {
                Button(i18n.t(S.startWatching)) { model.start() }
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
            .disabled(model.isWatching)

            if model.isWatching {
                Divider().frame(height: 16)
                PulsingDot()
                Text(i18n.t(S.watchingFor)).font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        if !model.isWatching && model.rows.isEmpty {
            EmptyStateView(
                symbol: "waveform.path.ecg",
                title: i18n.t(S.growth),
                message: i18n.t(S.growthHint)
            )
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    diskCard
                    if model.rows.isEmpty {
                        Text(i18n.t(S.noChangesYet))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)
                    } else {
                        ForEach(model.rows) { row in
                            GrowthRowView(row: row, largest: largest)
                        }
                    }
                    Text(i18n.t(S.growthNote))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                .padding(18)
            }
        }
    }

    private var largest: Int64 {
        max(1, model.rows.map { abs($0.delta) }.max() ?? 1)
    }

    private var diskCard: some View {
        HStack(spacing: 12) {
            Image(systemName: model.diskDelta <= 0 ? "arrow.down.circle" : "arrow.up.circle")
                .font(.system(size: 20))
                .foregroundStyle(model.diskDelta <= 0 ? Palette.warning : .green)

            VStack(alignment: .leading, spacing: 1) {
                Text(i18n.t(S.diskChange)).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(Format.signedBytes(model.diskDelta))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(model.diskDelta <= 0 ? Palette.warning : .green)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
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

private struct GrowthRowView: View {
    let row: GrowthRow
    let largest: Int64
    @EnvironmentObject private var i18n: I18n

    private var isGrowth: Bool { row.delta > 0 }
    private var fraction: Double { Double(abs(row.delta)) / Double(largest) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.head)
                    Text(i18n.t(S.eventCount(row.events)))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(Format.signedBytes(row.delta))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(isGrowth ? Palette.warning : .green)

                Button {
                    Cleaner.revealInFinder(URL(fileURLWithPath: row.path))
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(isGrowth ? Palette.warning : Color.green)
                    .frame(width: max(2, geometry.size.width * fraction))
                    .animation(.easeOut(duration: 0.5), value: fraction)
            }
            .frame(height: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.045)))
    }
}

private struct PulsingDot: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 7, height: 7)
            .opacity(on ? 1 : 0.25)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
