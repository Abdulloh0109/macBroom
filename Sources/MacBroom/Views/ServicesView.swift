import SwiftUI

struct ServicesView: View {
    @ObservedObject var model: ServicesModel
    @EnvironmentObject private var i18n: I18n
    @State private var pendingDisable: ServiceRecord?

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
            i18n.t(S.confirmDisable(pendingDisable?.label ?? "")),
            isPresented: Binding(get: { pendingDisable != nil }, set: { if !$0 { pendingDisable = nil } }),
            titleVisibility: .visible
        ) {
            Button(i18n.t(S.disableAndTrash), role: .destructive) {
                if let target = pendingDisable { model.disable(target) }
                pendingDisable = nil
            }
            Button(i18n.t(S.cancel), role: .cancel) { pendingDisable = nil }
        } message: {
            Text(i18n.t(S.serviceNote))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.services)).font(.system(size: 20, weight: .bold))
                Text(i18n.t(S.servicesIntro)).font(.system(size: 12)).foregroundStyle(.secondary)
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
            Toggle(i18n.t(S.showAppleServices), isOn: $model.showApple)
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

            Text(i18n.t(S.servicesSummary(model.visible.count, model.activeCount)))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.services.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text(i18n.t(S.loading)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.visible.isEmpty {
            EmptyStateView(
                symbol: "clock.arrow.circlepath",
                title: i18n.t(S.noServices),
                message: i18n.t(S.servicesIntro)
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    FailureList(failures: model.failures).padding(.horizontal, 18).padding(.top, 8)
                    ForEach(model.visible) { service in
                        row(service)
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
    }

    private func row(_ service: ServiceRecord) -> some View {
        HStack(spacing: 11) {
            Circle()
                .fill(service.isLoaded ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 7, height: 7)
                .help(i18n.t(service.isLoaded ? S.loaded : S.notLoaded))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(service.label).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Tag(text: scopeLabel(service.scope), tint: scopeTint(service.scope))
                    if service.runAtLoad {
                        Tag(text: i18n.t(S.startsAtLogin), tint: Palette.warning)
                    }
                }
                Text(service.program.isEmpty ? service.url.path : service.program)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                Cleaner.revealInFinder(service.url)
            } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(i18n.t(S.revealInFinder))

            if service.isRemovable {
                Button(i18n.t(S.disableAndTrash)) { pendingDisable = service }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Image(systemName: "lock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .help(i18n.t(S.readOnlyService))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func scopeLabel(_ scope: ServiceScope) -> String {
        switch scope {
        case .user: return i18n.t(S.scopeUser)
        case .admin: return i18n.t(S.scopeAdmin)
        case .system: return i18n.t(S.scopeSystem)
        }
    }

    private func scopeTint(_ scope: ServiceScope) -> Color {
        switch scope {
        case .user: return Palette.accent
        case .admin: return Palette.warning
        case .system: return .gray
        }
    }
}
