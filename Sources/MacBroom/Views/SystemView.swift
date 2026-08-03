import SwiftUI

struct SystemView: View {
    @ObservedObject var model: SystemModel
    @EnvironmentObject private var i18n: I18n

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 460), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    cpuCard
                    memoryCard
                    batteryCard
                    wifiCard
                    devicesCard
                    aboutCard
                }
                .padding(18)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(i18n.t(S.system)).font(.system(size: 20, weight: .bold))
                Text(i18n.t(S.systemIntro)).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(i18n.t(S.refresh)) { model.refresh() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    // MARK: - Cards

    private var cpuCard: some View {
        Card(title: i18n.t(S.cpuLoad), symbol: "cpu") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(model.cpu.busyPercent))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("%").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
            }

            SegmentBar(
                segments: [
                    .init(value: model.cpu.userPercent, color: Palette.accent),
                    .init(value: model.cpu.systemPercent, color: Palette.warning),
                ],
                total: 100
            )

            Row(i18n.t(S.userLabel), String(format: "%.1f%%", model.cpu.userPercent))
            Row(i18n.t(S.systemLabel), String(format: "%.1f%%", model.cpu.systemPercent))
            Row(i18n.t(S.idleLabel), String(format: "%.1f%%", model.cpu.idlePercent))
            if model.cpu.loadAverage.count == 3 {
                Row(
                    i18n.t(S.loadAverageLabel),
                    model.cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  ")
                )
            }
        }
    }

    private var memoryCard: some View {
        Card(title: i18n.t(S.memoryTitle), symbol: "memorychip") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.bytes(model.memory.used))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("/ \(Format.bytes(model.memory.total))")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer()
                Tag(text: pressureLabel, tint: pressureTint)
            }

            SegmentBar(
                segments: [
                    .init(value: Double(model.memory.app), color: Palette.accent),
                    .init(value: Double(model.memory.wired), color: Palette.accentDeep),
                    .init(value: Double(model.memory.compressed), color: Palette.warning),
                ],
                total: Double(max(model.memory.total, 1))
            )

            Row(i18n.t(S.userLabel), Format.bytes(model.memory.app))
            Row(i18n.t(S.wiredLabel), Format.bytes(model.memory.wired))
            Row(i18n.t(S.compressedLabel), Format.bytes(model.memory.compressed))
            Row(i18n.t(S.cachedLabel), Format.bytes(model.memory.cached))
            Row(i18n.t(S.swapLabel), Format.bytes(model.memory.swapUsed))
        }
    }

    private var pressureLabel: String {
        switch model.memory.pressure {
        case .low: return i18n.t(S.pressureLow)
        case .medium: return i18n.t(S.pressureMedium)
        case .high: return i18n.t(S.pressureHigh)
        }
    }

    private var pressureTint: Color {
        switch model.memory.pressure {
        case .low: return .green
        case .medium: return Palette.warning
        case .high: return .red
        }
    }

    @ViewBuilder
    private var batteryCard: some View {
        Card(title: i18n.t(S.batteryTitle), symbol: "battery.100") {
            if let battery = model.battery {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(battery.percentage)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Tag(
                        text: i18n.t(
                            battery.isCharging ? S.charging : (battery.isPluggedIn ? S.pluggedIn : S.onBattery)
                        ),
                        tint: battery.isCharging || battery.isPluggedIn ? .green : Palette.accent
                    )
                }

                SegmentBar(
                    segments: [
                        .init(
                            value: Double(battery.percentage),
                            color: battery.percentage <= 20 ? .red : .green
                        )
                    ],
                    total: 100
                )

                if let minutes = battery.minutesRemaining {
                    Row("", i18n.t(S.minutesLeft(minutes)))
                }
                if let health = battery.healthPercent {
                    Row(i18n.t(S.healthLabel), "\(health)%")
                }
                if let cycles = battery.cycleCount {
                    Row(i18n.t(S.cyclesLabel), "\(cycles)")
                }
                if let condition = battery.condition {
                    Row("", condition)
                }
            } else {
                Text(i18n.t(S.noBattery))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var wifiCard: some View {
        Card(title: i18n.t(S.networkTitle), symbol: "wifi") {
            if let wifi = model.wifi, wifi.isPowered {
                HStack(spacing: 8) {
                    SignalBars(bars: wifi.bars)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(wifi.ssid ?? "—")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        if wifi.ssid == nil {
                            Text(i18n.t(S.ssidHidden))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                }

                if let rssi = wifi.rssi { Row(i18n.t(S.signalLabel), "\(rssi) dBm") }
                if let rate = wifi.transmitRateMbps {
                    Row(i18n.t(S.speedLabel), "\(Int(rate)) Mbps")
                }
                if let channel = wifi.channel { Row(i18n.t(S.channelLabel), "\(channel)") }
                if let ip = wifi.ipAddress { Row(i18n.t(S.ipLabel), ip) }
            } else {
                Text(i18n.t(S.wifiOff)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private var devicesCard: some View {
        Card(title: i18n.t(S.devicesTitle), symbol: "cable.connector") {
            group(i18n.t(S.displaysLabel), model.displays)
            group(i18n.t(S.usbLabel), model.usb)
            group(i18n.t(S.bluetoothLabel), model.bluetooth)

            if model.isLoadingDevices {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(i18n.t(S.loading)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            } else if model.displays.isEmpty && model.usb.isEmpty && model.bluetooth.isEmpty {
                Text(i18n.t(S.noDevices)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ devices: [DeviceReading]) -> some View {
        if !devices.isEmpty {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
            ForEach(devices) { device in
                HStack(spacing: 6) {
                    Text(device.name).font(.system(size: 11)).lineLimit(1)
                    Spacer()
                    Text(device.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var aboutCard: some View {
        Card(title: i18n.t(S.aboutTitle), symbol: "laptopcomputer") {
            Row(i18n.t(S.chipLabel), model.host.chip)
            Row(i18n.t(S.coresLabel), model.host.cores)
            Row(i18n.t(S.modelLabel), model.host.model)
            Row(i18n.t(S.osLabel), model.host.osVersion)
            Row(i18n.t(S.uptimeLabel), uptimeText)
        }
    }

    private var uptimeText: String {
        let total = Int(model.host.uptime)
        return i18n.t(S.uptimeValue(total / 86_400, (total % 86_400) / 3_600, (total % 3_600) / 60))
    }
}

// MARK: - Building blocks

private struct Card<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .padding(.bottom, 2)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
    }
}

private struct Row: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// A stacked proportional bar — the shape both CPU and memory want.
private struct SegmentBar: View {
    struct Segment {
        let value: Double
        let color: Color
    }

    let segments: [Segment]
    let total: Double

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: max(0, geometry.size.width * segment.value / max(total, 0.001)))
                }
                Spacer(minLength: 0)
            }
            .animation(.easeOut(duration: 0.45), value: segments.map(\.value))
        }
        .frame(height: 6)
        .background(Color.primary.opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct SignalBars: View {
    let bars: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(level <= bars ? Palette.accent : Color.primary.opacity(0.15))
                    .frame(width: 3, height: CGFloat(4 + level * 3))
            }
        }
        .frame(height: 16)
    }
}
