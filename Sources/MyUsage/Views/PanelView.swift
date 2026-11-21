import SwiftUI

struct PanelView: View {
    @ObservedObject var service: UsageService
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if service.providerStateReadFailed {
                Text("Saved panel layout is unavailable. Collapse and order changes can't be saved.")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let providers = service.report?.providers, !providers.isEmpty {
                SettingsSectionView(service: service)
                Divider()
                providerList(providers)
            } else {
                emptyState
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { service.panelOpen = true }
        .onDisappear {
            service.panelOpen = false
            service.dragging = false
            service.applyPendingReportIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("My-Usage")
                .font(.system(size: 15, weight: .bold))
            if service.stale {
                Text("stale")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }
            Spacer()
            Button {
                service.refresh()
            } label: {
                Text(service.loading ? "Refreshing…" : "Refresh")
            }
            .disabled(service.loading)
            .controlSize(.small)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(emptyMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if !service.installed {
                Text("Requires `omp` from Oh My Pi on PATH.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button("Open Oh My Pi") {
                    if let url = URL(string: "https://omp.sh") {
                        openURL(url)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 20)
    }

    private var emptyMessage: String {
        if let report = service.report, report.providers.isEmpty {
            return "omp usage reported no providers."
        }
        if !service.error.isEmpty {
            return service.error
        }
        return "Waiting for the first OMP usage fetch…"
    }

    private func providerList(_ providers: [UsageProvider]) -> some View {
        List {
            ForEach(providers) { provider in
                ProviderSectionView(
                    provider: provider,
                    collapsed: service.isProviderCollapsed(provider.id),
                    showBars: service.settings.showPanelBars,
                    nowMs: service.nowMs,
                    onToggle: { service.toggleProviderCollapsed(provider.id) }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowSeparator(.hidden)
            }
            .onMove { indices, newOffset in
                guard let from = indices.first else { return }
                var to = newOffset
                if to > from { to -= 1 }
                service.dragging = true
                service.moveProvider(from: from, to: to)
                service.dragging = false
                service.applyPendingReportIfNeeded()
            }
        }
        .listStyle(.plain)
        .frame(minHeight: 120, maxHeight: 420)
        .scrollContentBackground(.hidden)
    }

    private var footer: some View {
        HStack {
            if let last = service.lastGoodAt {
                Text("Updated \(last, style: .time)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Quit My-Usage") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
        }
    }
}
