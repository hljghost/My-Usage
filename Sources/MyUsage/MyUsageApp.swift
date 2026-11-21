import SwiftUI

@main
struct MyUsageApp: App {
    @StateObject private var usageService: UsageService

    init() {
        let settings = SettingsStore()
        _usageService = StateObject(wrappedValue: UsageService(settingsStore: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(service: usageService)
        } label: {
            MenuBarLabel(service: usageService)
        }
        .menuBarExtraStyle(.window)
    }
}
