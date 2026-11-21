import XCTest
@testable import MyUsage

final class UsageModelTests: XCTestCase {
    private let fixture = """
    {
      "generatedAt": 1794542502143,
      "reports": [
        {
          "provider": "anthropic",
          "fetchedAt": 1794542501262,
          "limits": [
            {
              "id": "anthropic:5h",
              "label": "Claude 5 Hour",
              "window": { "id": "5h", "label": "5 Hour", "durationMs": 18000000, "resetsAt": 1794546000193 },
              "amount": { "used": 100, "limit": 100, "remaining": 0, "usedFraction": 1, "remainingFraction": 0, "unit": "percent" },
              "status": "exhausted"
            },
            {
              "id": "anthropic:7d",
              "label": "Claude 7 Day",
              "window": { "id": "7d", "label": "7 Day", "durationMs": 604800000, "resetsAt": 1794995999193 },
              "amount": { "used": 34, "limit": 100, "remaining": 66, "usedFraction": 0.34, "remainingFraction": 0.66, "unit": "percent" },
              "status": "ok"
            }
          ]
        },
        {
          "provider": "openai-codex",
          "fetchedAt": 1794542501262,
          "limits": [
            {
              "id": "openai-codex:primary",
              "label": "Primary",
              "window": { "id": "primary", "label": "Primary", "durationMs": 0, "resetsAt": null },
              "amount": { "used": 86, "limit": 100, "remaining": 14, "usedFraction": 0.86, "remainingFraction": 0.14, "unit": "percent" },
              "status": "ok"
            }
          ]
        },
        {
          "provider": "devin",
          "fetchedAt": 1794542501262,
          "limits": [
            {
              "id": "devin:quota:weekly",
              "label": "Weekly",
              "window": { "id": "weekly", "label": "Weekly", "durationMs": 604800000, "resetsAt": 1794995999193 },
              "amount": { "used": 100, "limit": 100, "remaining": 0, "usedFraction": 1, "remainingFraction": 0, "unit": "percent" },
              "status": "exhausted"
            }
          ]
        }
      ]
    }
    """

    func testParseFixture() {
        let report = UsageModel.parseUsageReport(fixture)
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.providers.count, 3)
        XCTAssertEqual(report?.providers[0].label, "Anthropic")
        XCTAssertEqual(report?.providers[0].limits.count, 2)
        XCTAssertEqual(report?.providers[0].limits[0].usedPct, 100)
        XCTAssertEqual(report?.providers[0].limits[1].usedPct, 34)
        XCTAssertEqual(report?.providers[0].limits[0].status, "exhausted")
        XCTAssertEqual(report?.providers[0].limits[0].resetsAt, 1_794_546_000_193)
        XCTAssertEqual(report?.providers[1].label, "OpenAI Codex")
        XCTAssertEqual(report?.providers[2].label, "Devin")
    }

    func testRemainingFractionFallback() {
        let noRem = UsageModel.parseUsageReport("""
        {"reports":[{"provider":"anthropic","limits":[
          {"id":"anthropic:5h","window":{"id":"5h"},"amount":{"usedFraction":0.34},"status":"ok"}
        ]}]}
        """)
        XCTAssertEqual(noRem?.providers[0].limits[0].remainingPct, 66)
        XCTAssertEqual(
            UsageModel.formatBarValue(noRem?.providers[0].limits[0], showAs: .left),
            "66% left"
        )

        let over = UsageModel.parseUsageReport("""
        {"reports":[{"provider":"anthropic","limits":[
          {"id":"anthropic:5h","window":{"id":"5h"},"amount":{"usedFraction":1.05,"remainingFraction":-0.05},"status":"exhausted"}
        ]}]}
        """)
        XCTAssertEqual(over?.providers[0].limits[0].remainingPct, 0)
        XCTAssertEqual(
            UsageModel.formatBarValue(over?.providers[0].limits[0], showAs: .left),
            "0% left"
        )
        XCTAssertEqual(over?.providers[0].limits[0].usedPct, 105)
    }

    func testParseFailures() {
        XCTAssertNil(UsageModel.parseUsageReport("not json"))
        XCTAssertNil(UsageModel.parseUsageReport("{}"))
        XCTAssertEqual(
            UsageModel.parseUsageReport("{\"reports\":[]}")?.providers.count,
            0
        )
    }

    func testPickBarAndPrimary() {
        let report = UsageModel.parseUsageReport(fixture)!
        let anth = report.providers[0]
        XCTAssertEqual(UsageModel.pickBarLimit(anth, barWindow: .auto)?.id, "anthropic:5h")
        XCTAssertEqual(UsageModel.pickBarLimit(anth, barWindow: .sevenDay)?.id, "anthropic:7d")
        XCTAssertEqual(UsageModel.pickBarLimit(anth, barWindow: .fiveHour)?.id, "anthropic:5h")
        XCTAssertEqual(UsageModel.pickPrimaryProvider(report, providerId: "anthropic")?.id, "anthropic")
        XCTAssertEqual(UsageModel.pickPrimaryProvider(report, providerId: "openai-codex")?.id, "openai-codex")
        XCTAssertEqual(UsageModel.pickPrimaryProvider(report, providerId: "missing")?.id, "anthropic")
        XCTAssertEqual(UsageModel.pickPrimaryProvider(report, providerId: "")?.id, "anthropic")
    }

    func testFormattersAndTone() {
        let report = UsageModel.parseUsageReport(fixture)!
        let anth = report.providers[0]
        XCTAssertEqual(UsageModel.formatBarValue(anth.limits[0], showAs: .used), "100%")
        XCTAssertEqual(UsageModel.formatBarValue(anth.limits[1], showAs: .left), "66% left")
        let now: Double = 1_794_542_502_143
        XCTAssertEqual(UsageModel.formatResetIn(resetsAt: 1_794_546_000_193, nowMs: now), "58m")
        XCTAssertEqual(
            UsageModel.formatResetIn(resetsAt: now + 2 * 3_600_000 + 14 * 60_000, nowMs: now),
            "2h 14m"
        )
        XCTAssertEqual(UsageModel.formatResetIn(resetsAt: now - 1000, nowMs: now), "resetting")
        XCTAssertEqual(UsageModel.limitTone(anth.limits[0]), .critical)
        XCTAssertEqual(UsageModel.limitTone(anth.limits[1]), .ok)
    }

    func testPollInterval() {
        XCTAssertEqual(UsageModel.pollIntervalMs(baseSec: 300, panelOpen: true, consecutiveFailures: 0), 300_000)
        XCTAssertEqual(UsageModel.pollIntervalMs(baseSec: 300, panelOpen: false, consecutiveFailures: 0), 600_000)
        XCTAssertEqual(UsageModel.pollIntervalMs(baseSec: 300, panelOpen: true, consecutiveFailures: 1), 600_000)
        XCTAssertEqual(UsageModel.pollIntervalMs(baseSec: 300, panelOpen: true, consecutiveFailures: 2), 1_200_000)
    }

    func testProviderOrderAndCollapse() {
        let report = UsageModel.parseUsageReport(fixture)!
        let ordered = UsageModel.applyProviderOrder(
            report.providers,
            order: ["devin", "anthropic"]
        )
        XCTAssertEqual(ordered.map(\.id), ["devin", "anthropic", "openai-codex"])

        let moved = UsageModel.moveProviderOrder(["a", "b", "c"], from: 0, to: 2)
        XCTAssertEqual(moved, ["b", "c", "a"])

        let defaults = UsageModel.defaultCollapsedProviders(report.providers)
        XCTAssertEqual(defaults["anthropic"], false)
        XCTAssertEqual(defaults["openai-codex"], false)
        XCTAssertEqual(defaults["devin"], true)

        let toggled = UsageModel.toggleCollapsed(defaults, providerId: "devin")
        XCTAssertEqual(toggled["devin"], false)

        let text = UsageModel.providerStateText(
            collapsed: ["devin": true],
            order: ["devin", "anthropic"]
        )
        let parsed = UsageModel.parseProviderState(text)
        XCTAssertEqual(parsed.collapsed["devin"], true)
        XCTAssertEqual(parsed.order, ["devin", "anthropic"])
    }
}
