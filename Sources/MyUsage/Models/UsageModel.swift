import Foundation

/// Pure functions over `omp usage --json` output.
/// Port of Ohm-My-Usage-archy-Pi `OmpUsageModel.js`.
enum UsageModel {
    static let providerLabels: [String: String] = [
        "anthropic": "Anthropic",
        "devin": "Devin",
        "google-antigravity": "Antigravity",
        "openai-codex": "OpenAI Codex",
        "xai-oauth": "xAI",
    ]

    static let providerShorts: [String: String] = [
        "anthropic": "cld",
        "devin": "devin",
        "google-antigravity": "agy",
        "openai-codex": "codex",
        "xai-oauth": "grok",
    ]

    static func providerLabel(_ providerId: String) -> String {
        if let known = providerLabels[providerId] {
            return known
        }
        return providerId
            .split { $0 == "-" || $0 == "_" }
            .map { part in
                guard let first = part.first else { return String(part) }
                return String(first).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    static func providerShort(_ providerId: String) -> String {
        if let known = providerShorts[providerId] {
            return known
        }
        return String(providerId.prefix(4))
    }

    /// Remaining percent for the "left" bar text. Uses remainingFraction when
    /// finite, else derives from usedFraction. Clamped to 0...100.
    static func remainingPercent(usedFraction: Double, remainingFraction: Double?) -> Int {
        let frac: Double
        if let remainingFraction, remainingFraction.isFinite {
            frac = remainingFraction
        } else {
            frac = 1 - usedFraction
        }
        return max(0, min(100, Int((frac * 100).rounded())))
    }

    static func normalizeLimit(_ raw: RawLimit) -> UsageLimit? {
        guard let usedFraction = raw.amount?.usedFraction, usedFraction.isFinite else {
            return nil
        }
        let win = raw.window
        return UsageLimit(
            id: raw.id ?? "",
            label: raw.label ?? raw.id ?? "",
            windowId: win?.id ?? "",
            windowLabel: win?.label ?? win?.id ?? "",
            usedPct: Int((usedFraction * 100).rounded()),
            remainingPct: remainingPercent(
                usedFraction: usedFraction,
                remainingFraction: raw.amount?.remainingFraction
            ),
            status: raw.status ?? "ok",
            resetsAt: win?.resetsAt
        )
    }

    static func parseUsageReport(_ jsonText: String) -> UsageReport? {
        guard let data = jsonText.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(RawUsagePayload.self, from: data) else {
            return nil
        }
        var providers: [UsageProvider] = []
        for rep in payload.reports {
            guard let providerId = rep.provider else { continue }
            var limits: [UsageLimit] = []
            for raw in rep.limits ?? [] {
                if let lim = normalizeLimit(raw) {
                    limits.append(lim)
                }
            }
            guard !limits.isEmpty else { continue }
            providers.append(
                UsageProvider(
                    id: providerId,
                    label: providerLabel(providerId),
                    limits: limits
                )
            )
        }
        return UsageReport(providers: providers)
    }

    static func pickBarLimit(_ provider: UsageProvider?, barWindow: BarWindow) -> UsageLimit? {
        guard let provider, !provider.limits.isEmpty else { return nil }
        if barWindow != .auto {
            if let match = provider.limits.first(where: { $0.windowId == barWindow.rawValue }) {
                return match
            }
        }
        return provider.limits.max(by: { $0.usedPct < $1.usedPct })
    }

    static func pickPrimaryProvider(_ report: UsageReport?, providerId: String) -> UsageProvider? {
        guard let report, !report.providers.isEmpty else { return nil }
        if !providerId.isEmpty,
           let exact = report.providers.first(where: { $0.id == providerId }) {
            return exact
        }
        var best: UsageProvider?
        var bestPct = -1
        for provider in report.providers {
            if let lim = pickBarLimit(provider, barWindow: .auto), lim.usedPct > bestPct {
                bestPct = lim.usedPct
                best = provider
            }
        }
        return best
    }

    static func formatBarValue(_ limit: UsageLimit?, showAs: ShowAs) -> String {
        guard let limit else { return "" }
        if showAs == .left {
            return "\(limit.remainingPct)% left"
        }
        return "\(limit.usedPct)%"
    }

    static func formatResetIn(resetsAt: Double?, nowMs: Double) -> String {
        guard let resetsAt else { return "" }
        let ms = resetsAt - nowMs
        if ms <= 0 { return "resetting" }
        let mins = Int(ms / 60_000)
        let h = mins / 60
        let m = mins % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    static func pollIntervalMs(
        baseSec: Int,
        panelOpen: Bool,
        consecutiveFailures: Int,
        maxBackoffMs: Int = 1_800_000
    ) -> Int {
        var base = max(30, baseSec) * 1000
        if !panelOpen {
            base *= 2
        }
        if consecutiveFailures > 0 {
            let factor = Int(pow(2.0, Double(consecutiveFailures)))
            base = max(base, min(maxBackoffMs, base * factor))
        }
        return base
    }

    static func limitTone(_ limit: UsageLimit?) -> LimitTone {
        guard let limit else { return .ok }
        if limit.status == "exhausted" || limit.usedPct >= 100 {
            return .critical
        }
        if limit.usedPct >= 90 {
            return .high
        }
        return .ok
    }

    static func defaultCollapsedProviders(_ providers: [UsageProvider]) -> [String: Bool] {
        var collapsed: [String: Bool] = [:]
        for (index, provider) in providers.enumerated() where !provider.id.isEmpty {
            collapsed[provider.id] = index >= 2
        }
        return collapsed
    }

    static func isCollapsed(_ collapsed: [String: Bool]?, providerId: String) -> Bool {
        collapsed?[providerId] == true
    }

    static func toggleCollapsed(_ collapsed: [String: Bool]?, providerId: String) -> [String: Bool] {
        var next = collapsed ?? [:]
        guard !providerId.isEmpty else { return next }
        next[providerId] = !isCollapsed(next, providerId: providerId)
        return next
    }

    static func mergeCollapseState(
        persisted: [String: Bool]?,
        defaults: [String: Bool]?
    ) -> [String: Bool] {
        var merged: [String: Bool] = [:]
        if let defaults {
            for (key, value) in defaults {
                merged[key] = value
            }
        }
        if let persisted {
            for (key, value) in persisted {
                merged[key] = value
            }
        }
        return merged
    }

    static func applyProviderOrder(
        _ providers: [UsageProvider],
        order: [String]?
    ) -> [UsageProvider] {
        var byId: [String: UsageProvider] = [:]
        for provider in providers where !provider.id.isEmpty && byId[provider.id] == nil {
            byId[provider.id] = provider
        }
        var out: [UsageProvider] = []
        if let order {
            for id in order {
                if let provider = byId.removeValue(forKey: id) {
                    out.append(provider)
                }
            }
        }
        for provider in providers {
            if byId[provider.id] != nil {
                out.append(provider)
                byId.removeValue(forKey: provider.id)
            }
        }
        return out
    }

    static func moveProviderOrder(_ order: [String]?, from: Int, to: Int) -> [String] {
        var list = (order ?? []).filter { !$0.isEmpty }
        guard from >= 0, from < list.count else { return list }
        let item = list.remove(at: from)
        let idx = max(0, min(to, list.count))
        list.insert(item, at: idx)
        return list
    }

    static func parseProviderState(_ jsonText: String?) -> ProviderPanelState {
        guard let jsonText, !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = jsonText.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data),
              let obj = root as? [String: Any]
        else {
            return .empty
        }

        if let version = obj["version"] as? Int, version == 2 {
            var collapsed: [String: Bool] = [:]
            if let raw = obj["collapsed"] as? [String: Any] {
                for (key, value) in raw {
                    if let bool = value as? Bool {
                        collapsed[key] = bool
                    }
                }
            }
            var order: [String] = []
            if let rawOrder = obj["order"] as? [Any] {
                for item in rawOrder {
                    if let id = item as? String, !id.isEmpty {
                        order.append(id)
                    }
                }
            }
            return ProviderPanelState(collapsed: collapsed, order: order)
        }

        // v1: flat id -> boolean map
        var collapsed: [String: Bool] = [:]
        for (key, value) in obj {
            if let bool = value as? Bool {
                collapsed[key] = bool
            }
        }
        return ProviderPanelState(collapsed: collapsed, order: [])
    }

    static func providerStateText(collapsed: [String: Bool]?, order: [String]?) -> String {
        var outCollapsed: [String: Bool] = [:]
        if let collapsed {
            for (key, value) in collapsed {
                outCollapsed[key] = value
            }
        }
        var outOrder: [String] = []
        if let order {
            for id in order where !id.isEmpty {
                outOrder.append(id)
            }
        }
        let payload: [String: Any] = [
            "version": 2,
            "collapsed": outCollapsed,
            "order": outOrder,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let text = String(data: data, encoding: .utf8)
        else {
            return #"{"version":2,"collapsed":{},"order":[]}"#
        }
        return text
    }
}

// MARK: - Raw JSON decoding (omp usage --json)

struct RawUsagePayload: Decodable {
    var generatedAt: Double?
    var reports: [RawProviderReport]
}

struct RawProviderReport: Decodable {
    var provider: String?
    var fetchedAt: Double?
    var limits: [RawLimit]?
}

struct RawLimit: Decodable {
    var id: String?
    var label: String?
    var window: RawWindow?
    var amount: RawAmount?
    var status: String?
}

struct RawWindow: Decodable {
    var id: String?
    var label: String?
    var durationMs: Double?
    var resetsAt: Double?
}

struct RawAmount: Decodable {
    var used: Double?
    var limit: Double?
    var remaining: Double?
    var usedFraction: Double?
    var remainingFraction: Double?
    var unit: String?
}
