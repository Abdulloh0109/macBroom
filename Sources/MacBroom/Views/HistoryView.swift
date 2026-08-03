import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: HistoryModel
    @EnvironmentObject private var i18n: I18n
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear { model.load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.history)).font(.system(size: 20, weight: .bold))
                Text(
                    model.sessions.isEmpty
                        ? i18n.t(S.historyIntro)
                        : i18n.t(S.sessionSummary(model.restorableTotal, Format.bytes(model.totalFreed)))
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer()
            if !model.sessions.isEmpty {
                Button(i18n.t(S.clearHistory)) { showClearConfirm = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .confirmationDialog(
            i18n.t(S.clearHistory),
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(i18n.t(S.clearHistory), role: .destructive) { model.clear() }
            Button(i18n.t(S.cancel), role: .cancel) {}
        } message: {
            Text(i18n.t(S.historyIntro))
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.sessions.isEmpty {
            EmptyStateView(
                symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                title: i18n.t(S.historyEmpty),
                message: i18n.t(S.historyEmptyBody)
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let error = model.lastError {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.warning)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                Button(i18n.t(S.openSettings)) {
                                    // Deep link to the exact pane, rather than telling
                                    // the user to go hunting through System Settings.
                                    if let url = URL(
                                        string:
                                            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
                                    ) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Spacer()
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8).fill(Palette.warning.opacity(0.12))
                        )
                    }

                    ForEach(model.sessions) { session in
                        SessionCard(session: session, model: model)
                    }
                }
                .padding(18)
            }
        }
    }
}

private struct SessionCard: View {
    let session: RemovalSession
    @ObservedObject var model: HistoryModel
    @EnvironmentObject private var i18n: I18n

    private var isExpanded: Bool { model.expanded.contains(session.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 15))
                    .frame(width: 22)
                    .foregroundStyle(session.restorableCount > 0 ? Palette.accent : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(i18n.t(session.source.label))
                            .font(.system(size: 13, weight: .semibold))
                        Text(Self.formatter.string(from: session.date))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Text(
                        i18n.t(S.sessionSummary(session.records.count, Format.bytes(session.freed)))
                            + (session.restorableCount > 0
                                ? " · " + i18n.t(S.restorableCount(session.restorableCount))
                                : "")
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }

                Spacer()

                if session.restorableCount > 0 {
                    Button(i18n.t(S.restoreAll)) { model.restoreAll(in: session) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { model.toggle(session.id) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            if isExpanded {
                Divider().padding(.leading, 46)
                VStack(spacing: 0) {
                    ForEach(session.records) { record in
                        RecordRow(record: record, model: model)
                    }
                    HStack {
                        Spacer()
                        Button(i18n.t(S.forgetSession)) { model.forget(session) }
                            .buttonStyle(.link)
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                }
                .padding(.bottom, 8)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.045)))
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

private struct RecordRow: View {
    let record: RemovalRecord
    @ObservedObject var model: HistoryModel
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(record.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(record.originalPath.replacingOccurrences(of: SafetyGuard.home.path, with: "~"))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            Text(Format.bytes(record.size))
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .trailing)

            if record.canRestore {
                // Manual escape hatch: if macOS blocks the move, Finder's own
                // "Put Back" always works, and this drops the user right on it.
                Button {
                    if let trashed = record.trashedPath {
                        Cleaner.revealInFinder(URL(fileURLWithPath: trashed))
                    }
                } label: {
                    Image(systemName: "trash").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(i18n.t(S.revealInTrash))

                Button(i18n.t(S.restore)) { model.restore(record) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Text(i18n.t(S.goneForever))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.leading, 32)
        .padding(.vertical, 4)
    }
}
