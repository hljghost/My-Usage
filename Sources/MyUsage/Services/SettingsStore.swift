import Foundation
import SwiftUI

/// User-facing settings persisted in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let prefix = "my-usage."

    @Published var settings: AppSettings {
        didSet { persist(settings) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.load(from: defaults, prefix: prefix)
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        var next = settings
        mutate(&next)
        settings = next
    }

    private func persist(_ settings: AppSettings) {
        defaults.set(settings.provider, forKey: prefix + "provider")
        defaults.set(settings.barWindow.rawValue, forKey: prefix + "barWindow")
        defaults.set(settings.showAs.rawValue, forKey: prefix + "showAs")
        defaults.set(settings.refreshIntervalSec, forKey: prefix + "refreshIntervalSec")
        defaults.set(settings.showProvider, forKey: prefix + "showProvider")
        defaults.set(settings.showBarValue, forKey: prefix + "showBarValue")
        defaults.set(settings.showPanelBars, forKey: prefix + "showPanelBars")
    }

    private static func load(from defaults: UserDefaults, prefix: String) -> AppSettings {
        var s = AppSettings.default
        if let provider = defaults.string(forKey: prefix + "provider") {
            s.provider = provider
        }
        if let raw = defaults.string(forKey: prefix + "barWindow"),
           let window = BarWindow(rawValue: raw) {
            s.barWindow = window
        }
        if let raw = defaults.string(forKey: prefix + "showAs"),
           let showAs = ShowAs(rawValue: raw) {
            s.showAs = showAs
        }
        let interval = defaults.integer(forKey: prefix + "refreshIntervalSec")
        if interval >= 30 {
            s.refreshIntervalSec = interval
        }
        if defaults.object(forKey: prefix + "showProvider") != nil {
            s.showProvider = defaults.bool(forKey: prefix + "showProvider")
        }
        if defaults.object(forKey: prefix + "showBarValue") != nil {
            s.showBarValue = defaults.bool(forKey: prefix + "showBarValue")
        }
        if defaults.object(forKey: prefix + "showPanelBars") != nil {
            s.showPanelBars = defaults.bool(forKey: prefix + "showPanelBars")
        }
        return s
    }
}
