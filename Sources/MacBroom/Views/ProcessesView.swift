import AppKit
import SwiftUI

struct ProcessesView: View {
    @ObservedObject var model: ProcessesModel
    @EnvironmentObject private var i18n: I18n
    @State private var pendingQuit: ProcessRecord?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
        }
        .onAppear { model.loadIfNeeded() }
        .confirmationDialog(
            i18n.t(S.confirmQuit(pendingQuit?.name ?? "")),
            isPresented: Binding(get: { pendingQuit != nil }, set: { if !$0 { pendingQuit = nil } }),
            titleVisibility: .visible
        ) {
            Button(i18n.t(S.quit), role: .destructive) {
                if let target = pendingQuit { model.quit(target) }
                pendingQuit = nil
            }
            Button(i18n.t(S.cancel), role: .cancel) { pendingQuit = nil }
        } message: {
            Text(i18n.t(S.quitNote))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.processes)).font(.system(size: 20, weight: .bold))
                Text(i18n.t(S.processesIntro)).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(i18n.t(S.refresh)) { model.reload() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Toggle(i18n.t(S.onlyBackground), isOn: $model.backgroundOnly)
                .font(.system(size: 11))
                .toggleStyle(.checkbox)

            Divider().frame(height: 16)

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(.secondary)
                TextField(i18n.t(S.searchApps), text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .frame(width: 160)
            }

            Spacer()

            Text(i18n.t(S.processSummary(model.visible.count, Format.bytes(model.totalMemory))))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.processes.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text(i18n.t(S.loading)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.visible.isEmpty {
            EmptyStateView(
                symbol: "bolt.horizontal.circle",
                title: i18n.t(S.processes),
                message: i18n.t(S.processesIntro)
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    FailureList(failures: model.failures).padding(.horizontal, 18).padding(.top, 8)
                    ForEach(model.visible) { process in
                        row(process)
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
    }

    private func row(_ process: ProcessRecord) -> some View {
        HStack(spacing: 11) {
            if let url = process.bundleURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(process.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    AdviceBadge(advice: process.advice)
                    if !process.ports.isEmpty {
                        Tag(text: i18n.t(S.listeningOnPort(process.ports)), tint: .green)
                    }
                }
                Text(process.bundleID ?? "pid \(process.pid)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(Format.age(process.launchDate))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 90, alignment: .trailing)

            Text(Format.bytes(process.memory))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)

            Button(i18n.t(S.quit)) { pendingQuit = process }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(process.advice == .keep)
                .help(i18n.t(process.advice.explanation))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
