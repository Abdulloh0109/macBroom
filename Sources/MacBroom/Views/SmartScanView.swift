import SwiftUI

struct SmartScanView: View {
    @ObservedObject var model: SmartScanModel
    @EnvironmentObject private var i18n: I18n
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if model.hasScanned && !model.categories.isEmpty {
                Divider()
                actionBar
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.smartScan))
                    .font(.system(size: 20, weight: .bold))
                Text(headline)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.isScanning {
                Button(i18n.t(S.stop)) { model.cancelScan() }
                    .buttonStyle(.bordered)
            } else {
                Button(i18n.t(model.hasScanned ? S.rescan : S.scan)) { model.scan() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.isCleaning)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var headline: String {
        if model.isScanning || model.isCleaning { return model.progressLabel(i18n.language) }
        if !model.hasScanned { return i18n.t(S.smartScanIntro) }
        if model.categories.isEmpty {
            return model.lastFreed > 0
                ? i18n.t(S.freedNothingLeft(Format.bytes(model.lastFreed)))
                : i18n.t(S.allCleanBody)
        }
        return i18n.t(S.reclaimable(Format.bytes(model.foundSize), model.categories.count))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.isScanning {
            VStack(spacing: 14) {
                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 320)
                Text(model.progressLabel(i18n.language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !model.hasScanned {
            EmptyStateView(
                symbol: "sparkles",
                title: i18n.t(S.readyTitle),
                message: i18n.t(S.readyBody)
            )
        } else if model.categories.isEmpty {
            EmptyStateView(
                symbol: "checkmark.seal",
                title: model.lastFreed > 0
                    ? i18n.t(S.freed(Format.bytes(model.lastFreed)))
                    : i18n.t(S.allCleanTitle),
                message: i18n.t(S.allCleanBody)
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    FailureList(failures: model.failures)
                        .padding(.horizontal, 18)
                    ForEach(model.categories) { category in
                        CategoryCard(category: category, model: model)
                            .padding(.horizontal, 18)
                    }
                }
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t(S.selectedItems(model.selectedCount)))
                    .font(.system(size: 12, weight: .medium))
                Text(Format.bytes(model.selectedSize))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
            }

            Spacer()

            Button(i18n.t(S.safeOnly)) { model.selectAllSafe() }
                .buttonStyle(.link)
            Button(i18n.t(S.none)) { model.deselectAll() }
                .buttonStyle(.link)

            Button(i18n.t(model.isCleaning ? S.cleaning : S.moveToTrash)) {
                showConfirm = true
            }
            .buttonStyle(PrimaryButtonStyle(enabled: model.selectedCount > 0 && !model.isCleaning))
            .disabled(model.selectedCount == 0 || model.isCleaning)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .confirmationDialog(
            i18n.t(S.confirmTrash(model.selectedCount, Format.bytes(model.selectedSize))),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(i18n.t(S.moveToTrash), role: .destructive) { model.cleanSelected() }
            Button(i18n.t(S.cancel), role: .cancel) {}
        } message: {
            Text(i18n.t(S.trashNote))
        }
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let category: ScanCategory
    @ObservedObject var model: SmartScanModel
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TriStateCheckbox(state: category.selectionState) {
                    model.setSelection(category.selectionState != .all, category: category.id)
                }

                Image(systemName: category.id.symbol)
                    .font(.system(size: 15))
                    .frame(width: 24)
                    .foregroundStyle(Palette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(i18n.t(category.id.title)).font(.system(size: 13, weight: .semibold))
                        RiskBadge(risk: category.id.risk)
                    }
                    Text(i18n.t(category.id.subtitle))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.bytes(category.totalSize))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(i18n.t(S.items(category.items.count)))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { model.toggleExpanded(category.id) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(category.isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            if category.isExpanded {
                Divider().padding(.leading, 48)
                VStack(spacing: 0) {
                    ForEach(category.items.prefix(60)) { item in
                        ItemRow(item: item) { model.toggleItem(item) }
                    }
                    if category.items.count > 60 {
                        Text(i18n.t(S.moreItems(category.items.count - 60)))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct ItemRow: View {
    let item: ScanItem
    let toggle: () -> Void
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        HStack(spacing: 10) {
            Checkbox(isOn: item.isSelected, action: toggle)
            Text(item.displayName)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
            if item.advice == .inUse {
                Tag(text: i18n.t(S.appIsOpen), tint: Palette.warning)
                    .help(i18n.t(S.appIsOpenWhy))
            }
            Spacer()
            Text(Format.age(item.modified))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(Format.bytes(item.size))
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
            Button {
                Cleaner.revealInFinder(item.url)
            } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(item.url.path)
        }
        .padding(.horizontal, 14)
        .padding(.leading, 34)
        .padding(.vertical, 4)
    }
}
