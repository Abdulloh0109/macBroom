import AppKit
import SwiftUI

struct DiskMapView: View {
    @ObservedObject var model: DiskMapModel
    @EnvironmentObject private var i18n: I18n
    @State private var hovered: String?

    /// At most this many bubbles; the tail is folded into one muted circle so a
    /// folder with 400 children still reads as a picture rather than confetti.
    private let bubbleLimit = 34

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            breadcrumb
            Divider()
            content
        }
    }

    // MARK: - Chrome

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
                .contentTransition(.numericText())
            }
            Spacer()
            if model.isScanning {
                Button(i18n.t(S.stop)) { model.cancel() }.buttonStyle(.bordered)
            } else {
                Button(i18n.t(model.hasScanned ? S.rescan : S.scan)) {
                    withAnimation(.easeOut(duration: 0.2)) { model.scan() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Button { chooseFolder() } label: {
                Image(systemName: "folder").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(model.root.path)

            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { model.goUp() }
            } label: {
                Label(i18n.t(S.up), systemImage: "arrow.up")
                    .font(.system(size: 11))
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
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                model.go(to: crumb.index)
                            }
                        } label: {
                            Text(crumb.name)
                                .font(
                                    .system(
                                        size: 11,
                                        weight: crumb.index == model.trail.count - 1 ? .semibold : .regular
                                    )
                                )
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
                    .contentTransition(.numericText())
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    // MARK: - Bubbles

    @ViewBuilder
    private var content: some View {
        if model.isScanning && model.tree == nil {
            ScanningIndicator(label: i18n.t(S.walking(model.root.lastPathComponent)))
        } else if !model.hasScanned {
            EmptyStateView(
                symbol: "circle.hexagongrid",
                title: i18n.t(S.diskMap),
                message: i18n.t(S.diskMapHint)
            )
        } else if model.nodes.isEmpty {
            EmptyStateView(
                symbol: "circle.dashed",
                title: i18n.t(S.emptyFolder),
                message: i18n.t(S.diskMapIntro)
            )
        } else {
            GeometryReader { geometry in
                let shown = Array(model.nodes.prefix(bubbleLimit))
                let restSize = model.nodes.dropFirst(bubbleLimit).reduce(Int64(0)) { $0 + $1.size }
                let sizes = shown.map(\.size) + (restSize > 0 ? [restSize] : [])
                let bubbles = CirclePack.layout(
                    sizes: sizes,
                    in: CGRect(origin: .zero, size: geometry.size)
                )

                ZStack {
                    ForEach(bubbles) { bubble in
                        let isRest = bubble.id >= shown.count
                        BubbleView(
                            node: isRest ? nil : shown[bubble.id],
                            restLabel: isRest ? i18n.t(S.moreItems(model.nodes.count - shown.count)) : nil,
                            restSize: restSize,
                            bubble: bubble,
                            hue: Self.hue(for: bubble.id),
                            isHovered: hovered == key(bubble.id, shown),
                            fraction: model.currentSize > 0
                                ? Double(isRest ? restSize : shown[bubble.id].size) / Double(model.currentSize)
                                : 0
                        )
                        .onHover { inside in
                            withAnimation(.easeOut(duration: 0.16)) {
                                hovered = inside ? key(bubble.id, shown) : nil
                            }
                        }
                        .onTapGesture {
                            guard !isRest else { return }
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                model.open(shown[bubble.id])
                            }
                        }
                        .contextMenu {
                            if !isRest {
                                Button(i18n.t(S.revealInFinder)) {
                                    Cleaner.revealInFinder(shown[bubble.id].url)
                                }
                            }
                        }
                    }
                }
                .id(model.currentPath)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.55).combined(with: .opacity),
                        removal: .scale(scale: 1.25).combined(with: .opacity)
                    )
                )
            }
            .padding(14)
        }
    }

    private func key(_ id: Int, _ shown: [MapNode]) -> String {
        id < shown.count ? shown[id].path : "__rest__"
    }

    /// Warm-to-cool spread that stays legible on the dark background.
    private static func hue(for index: Int) -> Double {
        let hues: [Double] = [0.47, 0.55, 0.60, 0.51, 0.09, 0.75, 0.34, 0.03, 0.86, 0.65]
        return hues[index % hues.count]
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

// MARK: - One bubble

private struct BubbleView: View {
    let node: MapNode?
    let restLabel: String?
    let restSize: Int64
    let bubble: CirclePack.Bubble
    let hue: Double
    let isHovered: Bool
    let fraction: Double

    @State private var hasAppeared = false

    private var isFolder: Bool { node?.isDirectory ?? false }
    private var name: String { node?.name ?? restLabel ?? "" }
    private var size: Int64 { node?.size ?? restSize }

    private var fill: some ShapeStyle {
        // A soft top-left highlight is what makes a flat disc read as a sphere.
        RadialGradient(
            colors: node == nil
                ? [Color.gray.opacity(0.34), Color.gray.opacity(0.16)]
                : [
                    Color(hue: hue, saturation: isFolder ? 0.52 : 0.26, brightness: isHovered ? 0.92 : 0.80),
                    Color(hue: hue, saturation: isFolder ? 0.78 : 0.38, brightness: isHovered ? 0.62 : 0.48),
                ],
            center: UnitPoint(x: 0.32, y: 0.26),
            startRadius: 0,
            endRadius: bubble.radius * 1.6
        )
    }

    private var showsLabel: Bool { bubble.radius > 26 }
    private var showsSize: Bool { bubble.radius > 38 }
    private var showsPercent: Bool { bubble.radius > 54 && fraction >= 0.015 }

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(isHovered ? 0.35 : 0.14), lineWidth: 1)
                )
                .shadow(
                    color: Color(hue: hue, saturation: 0.7, brightness: 0.5)
                        .opacity(isHovered ? 0.55 : 0.25),
                    radius: isHovered ? 16 : 7,
                    y: isHovered ? 5 : 3
                )

            if showsLabel {
                VStack(spacing: 1) {
                    Text(name)
                        .font(.system(size: min(14, max(9, bubble.radius * 0.20)), weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if showsSize {
                        Text(Format.bytes(size))
                            .font(.system(size: min(12, max(8, bubble.radius * 0.16)), design: .rounded))
                            .monospacedDigit()
                            .opacity(0.9)
                    }
                    if showsPercent {
                        Text("\(Int(fraction * 100))%")
                            .font(.system(size: min(10, max(7, bubble.radius * 0.13))))
                            .opacity(0.72)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(maxWidth: bubble.radius * 1.75)
            }
        }
        .frame(width: bubble.radius * 2, height: bubble.radius * 2)
        .scaleEffect(hasAppeared ? (isHovered ? 1.06 : 1) : 0.1)
        .opacity(hasAppeared ? 1 : 0)
        .position(bubble.center)
        .help("\(name) — \(Format.bytes(size))")
        .onAppear {
            // Stagger by size so the big ones land first and the small ones settle in.
            withAnimation(
                .spring(response: 0.5, dampingFraction: 0.7)
                    .delay(Double(bubble.id) * 0.018)
            ) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Scanning state

private struct ScanningIndicator: View {
    let label: String
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(Palette.accent.opacity(0.35 - Double(ring) * 0.1), lineWidth: 2)
                        .frame(width: 34 + CGFloat(ring) * 26, height: 34 + CGFloat(ring) * 26)
                        .scaleEffect(pulse ? 1.12 : 0.92)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                                .delay(Double(ring) * 0.18),
                            value: pulse
                        )
                }
                Circle()
                    .fill(Palette.gradient)
                    .frame(width: 22, height: 22)
            }
            .frame(height: 110)

            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}
