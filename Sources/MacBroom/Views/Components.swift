import SwiftUI

enum Palette {
    static let accent = Color(red: 0.20, green: 0.78, blue: 0.72)
    static let accentDeep = Color(red: 0.13, green: 0.47, blue: 0.85)
    static let warning = Color(red: 0.98, green: 0.68, blue: 0.25)

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Ring showing how full the startup volume is.
struct DiskGauge: View {
    let disk: DiskInfo
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(0.01, disk.usedFraction))
                    .stroke(Palette.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: disk.usedFraction)

                VStack(spacing: 1) {
                    Text(Format.bytes(disk.available))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(i18n.t(S.free))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 92)

            VStack(spacing: 2) {
                Text(i18n.t(S.diskUsed(Format.bytes(disk.used), Format.bytes(disk.total))))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if disk.purgeable > 1_000_000_000 {
                    Text(i18n.t(S.purgeableHint(Format.bytes(disk.purgeable))))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .multilineTextAlignment(.center)
        }
    }
}

struct TriStateCheckbox: View {
    let state: ScanCategory.SelectionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    // An unchecked box used to be filled with Color.clear, which
                    // SwiftUI does not hit-test: only the 1pt border responded to
                    // clicks, so ticking a box was mostly luck. A near-transparent
                    // fill is hit-testable and still looks empty.
                    .fill(
                        state == .none
                            ? AnyShapeStyle(Color.primary.opacity(0.06))
                            : AnyShapeStyle(Palette.gradient)
                    )
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1)
                if state == .all {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                } else if state == .partial {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 16, height: 16)
            // Comfortable target: the box stays 16pt, the clickable area is 24pt.
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Checkbox: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        TriStateCheckbox(state: isOn ? .all : .none, action: action)
    }
}

struct RiskBadge: View {
    let risk: RiskLevel
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        Text(i18n.t(risk.label))
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(
                    risk == .safe
                        ? Palette.accent.opacity(0.18)
                        : Palette.warning.opacity(0.22)
                )
            )
            .foregroundStyle(risk == .safe ? Palette.accent : Palette.warning)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(
                    enabled ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.gray.opacity(0.4))
                )
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// "Can remove" / "Left over" / "In use" / "Keep" — the plain-language verdict.
struct AdviceBadge: View {
    let advice: Advice
    @EnvironmentObject private var i18n: I18n

    private var tint: Color {
        switch advice {
        case .removable: return Palette.accent
        case .leftover: return Palette.warning
        case .inUse: return .green
        case .keep: return .secondary
        }
    }

    var body: some View {
        Tag(text: i18n.t(advice.label), tint: tint)
            .help(i18n.t(advice.explanation))
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.8))
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FailureList: View {
    let failures: [Cleaner.Failure]
    @EnvironmentObject private var i18n: I18n

    var body: some View {
        if !failures.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(i18n.t(S.couldNotRemove(failures.count)), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.warning)
                ForEach(failures.prefix(4)) { failure in
                    Text("• \(failure.reason)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.warning.opacity(0.12)))
        }
    }
}
