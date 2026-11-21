import Foundation

/// Persists provider collapse + order to `~/.config/my-usage/state.json`.
final class PanelStateStore: Sendable {
    let fileURL: URL
    private let maxBytes = 65_536

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.fileURL = home
                .appendingPathComponent(".config")
                .appendingPathComponent("my-usage")
                .appendingPathComponent("state.json")
        }
    }

    func load() -> Result<ProviderPanelState, Error> {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            return .success(.empty)
        }
        do {
            let attrs = try fm.attributesOfItem(atPath: fileURL.path)
            if let size = attrs[.size] as? NSNumber, size.intValue > maxBytes {
                return .failure(StoreError.tooLarge)
            }
            let data = try Data(contentsOf: fileURL)
            let text = String(data: data, encoding: .utf8) ?? ""
            return .success(UsageModel.parseProviderState(text))
        } catch {
            return .failure(error)
        }
    }

    func save(collapsed: [String: Bool], order: [String]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let text = UsageModel.providerStateText(collapsed: collapsed, order: order)
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    enum StoreError: Error {
        case tooLarge
    }
}
