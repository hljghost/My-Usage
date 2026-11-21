import SwiftUI

struct ProviderSectionView: View {
    let provider: UsageProvider
    let collapsed: Bool
    let showBars: Bool
    let nowMs: Double
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .help("Drag to reorder")
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(provider.label)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(peakPct)%")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(peakColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !collapsed {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(provider.limits) { limit in
                        LimitRow(limit: limit, showBars: showBars, nowMs: nowMs)
                    }
                }
                .padding(.leading, 18)
            }
        }
    }

    private var peakPct: Int {
        provider.limits.map(\.usedPct).max() ?? 0
    }

    private var peakColor: Color {
        let tone = UsageModel.limitTone(
            provider.limits.max(by: { $0.usedPct < $1.usedPct })
        )
        switch tone {
        case .critical: return .red
        case .high: return .orange
        case .ok: return .secondary
        }
    }
}

private struct LimitRow: View {
    let limit: UsageLimit
    let showBars: Bool
    let nowMs: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(limit.windowLabel.isEmpty ? limit.label : limit.windowLabel)
                    .font(.system(size: 12))
                Spacer()
                Text("\(limit.usedPct)%")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(valueColor)
                if let reset = resetText, !reset.isEmpty {
                    Text("· \(reset)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            if showBars {
                ProgressView(value: min(1, Double(limit.usedPct) / 100.0))
                    .tint(valueColor)
                    .controlSize(.small)
            }
        }
    }

    private var resetText: String? {
        let text = UsageModel.formatResetIn(resetsAt: limit.resetsAt, nowMs: nowMs)
        return text.isEmpty ? nil : text
    }

    private var valueColor: Color {
        switch UsageModel.limitTone(limit) {
        case .critical: return .red
        case .high: return .orange
        case .ok: return .primary
        }
    }
}
