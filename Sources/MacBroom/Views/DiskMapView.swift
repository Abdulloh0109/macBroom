import AppKit
import SwiftUI

struct DiskMapView: View {
    @ObservedObject var model: DiskMapModel
    @EnvironmentObject private var i18n: I18n
    @State private var hovered: String?

    /// Distinct hues so neighbouring tiles never blur into one another.
    private static let hues: [Double] = [0.47, 0.55, 0.60, 0.10, 0.75, 0.33, 0.03, 0.85]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            breadcrumb
            Divider()
            content
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.diskMap)).font(.system(size: 20, weight: .bold))
                Text(
                    model.isScanning
                        ? i18n.t(S.scanningTree(model.scannedFiles, Format.bytes(model.scannedBytes)))
                        : i18n.t(S.diskMapIntro)
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

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Button {
                chooseFolder()
            } label: {
                Image(systemName: "folder").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(model.root.path)

            Button {
                model.goUp()
            } label: {
                Label(i18n.t(S.up), systemImage: "arrow.up").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.canGoUp ? Palette.accent : .secondary)
            .disabled(!model.canGoUp)

            Divider().frame(height: 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(model.breadcrumb, id: \.index) { crumb in
                        if crumb.index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            model.go(to: crumb.index)
                        } label: {
                            Text(crumb.name)
                                .font(.system(size: 11, weight: crumb.index == model.trail.count - 1 ? .semibold : .regular))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(crumb.index == model.trail.count - 1 ? .primary : .secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            if model.hasScanned {
                Text(Format.bytes(model.currentSize))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var content: some View {
        if model.isScanning && model.tree == nil {
            VStack(spacing: 10) {
                ProgressView()
                Text(i18n.t(S.walking(model.root.lastPathComponent)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !model.hasScanned {
            EmptyStateView(
                symbol: "square.grid.3x3.topleft.filled",
                title: i18n.t(S.diskMap),
                message: i18n.t(S.diskMapHint)
            )
        } else if model.nodes.isEmpty {
            EmptyStateView(
                symbol: "square.dashed",
                title: i18n.t(S.emptyFolder),
                message: i18n.t(S.diskMapIntro)
            )
        } else {
            GeometryReader { geometry in
                let nodes = model.nodes
                let bounds = CGRect(origin: .zero, size: geometry.size)
                let tiles = Treemap.layout(sizes: nodes.map(\.size), in: bounds)

                ZStack(alignment: .topLeading) {
                    ForEach(tiles, id: \.index) { tile in
                        let node = nodes[tile.index]
                        TileView(
                            node: node,
                            rect: tile.rect,
                            hue: Self.hues[tile.index % Self.hues.count],
                            isHovered: hovered == node.path,
                            fraction: model.currentSize > 0
                                ? Double(node.size) / Double(model.currentSize) : 0
                        )
                        .onHover { inside in hovered = inside ? node.path : nil }
                        .onTapGesture { model.open(node) }
                        .contextMenu {
                            Button(i18n.t(S.revealInFinder)) { Cleaner.revealInFinder(node.url) }
                        }
                    }
                }
            }
            .padding(10)
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

private struct TileView: View {
    let node: MapNode
    let rect: CGRect
    let hue: Double
    let isHovered: Bool
    let fraction: Double

    private var fill: Color {
        Color(hue: hue, saturation: node.isDirectory ? 0.45 : 0.18, brightness: isHovered ? 0.72 : 0.55)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if rect.width > 64 && rect.height > 30 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(node.name)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(Format.bytes(node.size))
                            .font(.system(size: 10, design: .rounded))
                            .monospacedDigit()
                            .opacity(0.85)
                        if rect.height > 56 && fraction >= 0.02 {
                            Text("\(Int(fraction * 100))%")
                                .font(.system(size: 9))
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(6)
                }
            }
            .help("\(node.name) — \(Format.bytes(node.size))")
            .frame(width: max(1, rect.width), height: max(1, rect.height))
            .offset(x: rect.minX, y: rect.minY)
    }
}
