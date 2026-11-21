import Foundation
import SwiftUI

/// Polls `omp usage --json`, derives the menu-bar readout, and owns panel state.
@MainActor
final class UsageService: ObservableObject {
    @Published private(set) var report: UsageReport?
    @Published private(set) var primaryProvider: UsageProvider?
    @Published private(set) var barLimit: UsageLimit?
    @Published private(set) var barText: String = ""
    @Published private(set) var barTone: LimitTone = .ok
    @Published private(set) var barShort: String = ""
    @Published private(set) var barDisplayText: String = "—"
    @Published private(set) var installed = false
    @Published private(set) var loading = false
    @Published private(set) var stale = false
    @Published private(set) var error: String = ""
    @Published private(set) var lastGoodAt: Date?
    @Published var panelOpen = false {
        didSet { handlePanelOpenChange() }
    }
    @Published private(set) var collapsedProviders: [String: Bool] = [:]
    @Published private(set) var providerStateLoaded = false
    @Published private(set) var providerStateReadFailed = false
    @Published var dragging = false
    @Published var nowMs: Double = Date().timeIntervalSince1970 * 1000

    private let settingsStore: SettingsStore
    private let panelStateStore: PanelStateStore
    private let ompClient: OmpClient
    private var persistedCollapsed: [String: Bool] = [:]
    private var persistedOrder: [String] = []
    private var consecutiveFailures = 0
    private var lastFetchMs: Double = 0
    private var pendingReport: UsageReport?
    private var pollTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private let maxBackoffMs = 1_800_000

    var settings: AppSettings { settingsStore.settings }

    init(
        settingsStore: SettingsStore,
        panelStateStore: PanelStateStore = PanelStateStore(),
        ompClient: OmpClient = OmpClient()
    ) {
        self.settingsStore = settingsStore
        self.panelStateStore = panelStateStore
        self.ompClient = ompClient
        loadProviderState()
        startPolling()
        startClock()
    }

    deinit {
        pollTask?.cancel()
        clockTask?.cancel()
        refreshTask?.cancel()
    }

    // MARK: - Public API

    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            await self?.performRefresh()
            self?.refreshTask = nil
        }
    }

    func applyPendingReportIfNeeded() {
        guard let pending = pendingReport else { return }
        pendingReport = nil
        applyParsedReport(pending)
    }

    func isProviderCollapsed(_ providerId: String) -> Bool {
        UsageModel.isCollapsed(collapsedProviders, providerId: providerId)
    }

    func toggleProviderCollapsed(_ providerId: String) {
        let next = UsageModel.toggleCollapsed(collapsedProviders, providerId: providerId)
        collapsedProviders = next
        var p = persistedCollapsed
        p[providerId] = UsageModel.isCollapsed(next, providerId: providerId)
        persistedCollapsed = p
        saveProviderState()
    }

    func moveProvider(from: Int, to: Int) {
        guard let providers = report?.providers else { return }
        let ids = providers.map(\.id)
        let next = UsageModel.moveProviderOrder(ids, from: from, to: to)
        guard next != ids else { return }
        persistedOrder = next
        report = UsageReport(providers: UsageModel.applyProviderOrder(providers, order: next))
        saveProviderState()
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        settingsStore.update(mutate)
        deriveBar()
        // Poll cadence may have changed.
        restartPollingSoon()
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            // Immediate first fetch.
            self?.refresh()
            while !Task.isCancelled {
                guard let self else { return }
                let interval = UsageModel.pollIntervalMs(
                    baseSec: self.settings.refreshIntervalSec,
                    panelOpen: self.panelOpen,
                    consecutiveFailures: self.consecutiveFailures,
                    maxBackoffMs: self.maxBackoffMs
                )
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000)
                guard !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    private func restartPollingSoon() {
        startPolling()
    }

    private func handlePanelOpenChange() {
        if panelOpen {
            let now = Date().timeIntervalSince1970 * 1000
            let baseMs = Double(max(30, settings.refreshIntervalSec) * 1000)
            if lastFetchMs == 0 || now - lastFetchMs > baseMs {
                refresh()
            }
        }
        // Interval depends on panelOpen — restart the sleep loop.
        restartPollingSoon()
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.nowMs = Date().timeIntervalSince1970 * 1000
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func performRefresh() async {
        loading = true
        do {
            let json = try await ompClient.fetchUsageJSON()
            loading = false
            guard let parsed = UsageModel.parseUsageReport(json) else {
                handleFetchFailure(message: "OMP usage came back in a shape I don't recognise.")
                return
            }
            consecutiveFailures = 0
            lastFetchMs = Date().timeIntervalSince1970 * 1000
            stale = false
            error = ""
            installed = true
            lastGoodAt = Date()
            if dragging {
                pendingReport = parsed
                return
            }
            applyParsedReport(parsed)
        } catch {
            loading = false
            handleFetchFailure(message: "Couldn't read OMP usage just now.")
        }
    }

    private func handleFetchFailure(message: String) {
        consecutiveFailures += 1
        stale = report != nil
        if report == nil {
            error = message
            deriveBar()
        }
    }

    private func applyParsedReport(_ parsed: UsageReport) {
        report = parsed
        reconcileCollapseState()
        applyProviderOrder()
        deriveBar()
    }

    // MARK: - Bar derivation

    private func deriveBar() {
        primaryProvider = UsageModel.pickPrimaryProvider(report, providerId: settings.provider)
        if let provider = primaryProvider {
            barLimit = UsageModel.pickBarLimit(provider, barWindow: settings.barWindow)
        } else {
            barLimit = nil
        }
        barText = settings.showBarValue ? UsageModel.formatBarValue(barLimit, showAs: settings.showAs) : ""
        barTone = UsageModel.limitTone(barLimit)
        barShort = primaryProvider.map { UsageModel.providerShort($0.id) } ?? ""
        barDisplayText = makeBarDisplayText()
    }

    private func makeBarDisplayText() -> String {
        guard installed else { return "—" }
        let short = barShort
        let value = barText
        if !settings.showBarValue {
            if settings.showProvider {
                return short.isEmpty ? "—" : short
            }
            return ""
        }
        if value.isEmpty { return "—" }
        if settings.showProvider {
            return short.isEmpty ? value : "\(short) \(value)"
        }
        return value
    }

    // MARK: - Panel state

    private func loadProviderState() {
        switch panelStateStore.load() {
        case .success(let state):
            providerStateLoaded = true
            providerStateReadFailed = false
            persistedCollapsed = state.collapsed
            persistedOrder = state.order
            reconcileCollapseState()
            applyProviderOrder()
        case .failure:
            providerStateReadFailed = true
            reconcileCollapseState()
            applyProviderOrder()
        }
    }

    private func saveProviderState() {
        guard providerStateLoaded else { return }
        do {
            try panelStateStore.save(collapsed: collapsedProviders, order: persistedOrder)
        } catch {
            // Non-fatal: keep working in memory.
        }
    }

    private func reconcileCollapseState() {
        guard let providers = report?.providers else { return }
        collapsedProviders = UsageModel.mergeCollapseState(
            persisted: persistedCollapsed,
            defaults: UsageModel.defaultCollapsedProviders(providers)
        )
    }

    private func applyProviderOrder() {
        guard let providers = report?.providers else { return }
        report = UsageReport(
            providers: UsageModel.applyProviderOrder(providers, order: persistedOrder)
        )
    }
}
