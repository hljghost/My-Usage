import SwiftUI

struct SettingsSectionView: View {
    @ObservedObject var service: UsageService
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Settings")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                settingsBody
            }
        }
    }

    @ViewBuilder
    private var settingsBody: some View {
        let settings = service.settings
        let providers = service.report?.providers ?? []

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bar provider")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                FlowChips {
                    ForEach(providers) { provider in
                        chip(
                            title: UsageModel.providerShort(provider.id),
                            selected: settings.provider == provider.id
                        ) {
                            service.updateSettings { $0.provider = provider.id }
                        }
                    }
                    chip(title: "Auto", selected: settings.provider.isEmpty) {
                        service.updateSettings { $0.provider = "" }
                    }
                }
            }

            settingRow(title: "Bar window") {
                HStack(spacing: 6) {
                    ForEach(BarWindow.allCases) { window in
                        chip(title: window.title, selected: settings.barWindow == window) {
                            service.updateSettings { $0.barWindow = window }
                        }
                    }
                }
            }

            settingRow(title: "Show as") {
                HStack(spacing: 6) {
                    ForEach(ShowAs.allCases) { mode in
                        chip(title: mode.title, selected: settings.showAs == mode) {
                            service.updateSettings { $0.showAs = mode }
                        }
                    }
                }
            }

            toggleRow(title: "Show provider name", isOn: settings.showProvider) {
                service.updateSettings { $0.showProvider.toggle() }
            }
            toggleRow(title: "Show value in bar", isOn: settings.showBarValue) {
                service.updateSettings { $0.showBarValue.toggle() }
            }
            toggleRow(title: "Show bars in panel", isOn: settings.showPanelBars) {
                service.updateSettings { $0.showPanelBars.toggle() }
            }

            HStack {
                Text("Refresh interval")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.refreshIntervalSec },
                    set: { value in service.updateSettings { $0.refreshIntervalSec = value } }
                )) {
                    Text("1 min").tag(60)
                    Text("5 min").tag(300)
                    Text("10 min").tag(600)
                    Text("30 min").tag(1800)
                }
                .labelsHidden()
                .frame(width: 100)
            }
        }
        .padding(.leading, 4)
    }

    private func settingRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }

    private func toggleRow(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button(isOn ? "On" : "Off", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text((selected ? "✓ " : "") + title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Simple wrapping chip row without an external layout dependency.
private struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        // Keep it simple: a wrapping LazyVGrid of flexible chips.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 56), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            content
        }
    }
}
