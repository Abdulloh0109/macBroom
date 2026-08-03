import SwiftUI

struct SystemDataView: View {
    @ObservedObject var model: SystemDataModel
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { model.scanIfNeeded() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.systemData)).font(.system(size: 20, weight: .bold))
                Text(i18n.t(S.systemDataIntro))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                purgeableCard
                noteCard

                if model.isScanning && model.entries.isEmpty {
                    ProgressView().padding(.top, 20)
                }

                ForEach(model.entries) { entry in
                    EntryRow(entry: entry, model: model)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Purgeable

    private var purgeableCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.warning)
                Text(i18n.t(S.purgeableTitle)).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(Format.bytes(model.disk.purgeable))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.warning)
            }

            Text(i18n.t(S.purgeableExplain))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("Time Machine:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(
                    model.snapshotCount == 0
                        ? i18n.t(S.noSnapshots)
                        : i18n.t(S.items(model.snapshotCount))
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(model.snapshotCount == 0 ? .green : Palette.warning)
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.warning.opacity(0.10)))
    }

    private var noteCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 12))
                .foregroundStyle(Palette.accent)
            Text(i18n.t(S.systemDataWhy))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }
}

// MARK: - One location

private struct EntryRow: View {
    let entry: SystemDataEntry
    @ObservedObject var model: SystemDataModel
    @EnvironmentObject private var i18n: I18n

    private var isCopied: Bool { model.justCopied == entry.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName).font(.system(size: 13, weight: .semibold))
                    Text(entry.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if entry.size > 0 {
                    Text(Format.bytes(entry.size))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else {
                    ProgressView().controlSize(.small)
                }
            }

            Text(i18n.t(entry.explanation))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = entry.extraDetail {
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
            }

            switch entry.action {
            case .explainOnly:
                Tag(text: i18n.t(S.infoOnly), tint: .secondary)

            case .command(let command):
                HStack(spacing: 8) {
                    Text(command)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.25)))
                        .textSelection(.enabled)

                    Button {
                        model.copy(command, id: entry.id)
                    } label: {
                        Label(
                            i18n.t(isCopied ? S.copied : S.copyCommand),
                            systemImage: isCopied ? "checkmark" : "doc.on.doc"
                        )
                        .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(isCopied ? .green : nil)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
    }
}
