import Foundation

/// Tone used to colour the menu-bar readout.
enum LimitTone: String, Equatable, Sendable {
    case ok
    case high
    case critical
}

struct UsageAmount: Equatable, Sendable {
    var used: Double?
    var limit: Double?
    var remaining: Double?
    var usedFraction: Double
    var remainingFraction: Double?
    var unit: String?
}

struct UsageWindow: Equatable, Sendable {
    var id: String
    var label: String
    var durationMs: Double?
    var resetsAt: Double?
}

struct UsageLimit: Identifiable, Equatable, Sendable {
    var id: String
    var label: String
    var windowId: String
    var windowLabel: String
    var usedPct: Int
    var remainingPct: Int
    var status: String
    var resetsAt: Double?
}

struct UsageProvider: Identifiable, Equatable, Sendable {
    var id: String
    var label: String
    var limits: [UsageLimit]
}

struct UsageReport: Equatable, Sendable {
    var providers: [UsageProvider]
}

struct ProviderPanelState: Equatable, Sendable {
    var collapsed: [String: Bool]
    var order: [String]

    static let empty = ProviderPanelState(collapsed: [:], order: [])
}

enum BarWindow: String, CaseIterable, Identifiable, Sendable {
    case auto
    case fiveHour = "5h"
    case sevenDay = "7d"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .fiveHour: return "5h"
        case .sevenDay: return "7d"
        }
    }
}

enum ShowAs: String, CaseIterable, Identifiable, Sendable {
    case used
    case left

    var id: String { rawValue }

    var title: String {
        switch self {
        case .used: return "Used"
        case .left: return "Left"
        }
    }
}

struct AppSettings: Equatable, Sendable {
    /// Empty string means Auto (highest usage).
    var provider: String = "anthropic"
    var barWindow: BarWindow = .auto
    var showAs: ShowAs = .used
    var refreshIntervalSec: Int = 300
    var showProvider: Bool = false
    var showBarValue: Bool = true
    var showPanelBars: Bool = true

    static let `default` = AppSettings()
}
