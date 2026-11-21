import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var service: UsageService

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 11, weight: .semibold))
            if !service.barDisplayText.isEmpty {
                Text(service.barDisplayText)
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            }
        }
        .foregroundStyle(toneColor)
        .help(tooltip)
    }

    private var toneColor: Color {
        switch service.barTone {
        case .critical:
            return Color.red
        case .high:
            return Color.red.opacity(0.65)
        case .ok:
            return Color.primary
        }
    }

    private var tooltip: String {
        if service.installed {
            return service.stale ? "My-Usage (stale — last fetch failed)" : "My-Usage"
        }
        if !service.error.isEmpty {
            return "My-Usage — first fetch failed (retrying)"
        }
        return "My-Usage — waiting for the first fetch"
    }
}
