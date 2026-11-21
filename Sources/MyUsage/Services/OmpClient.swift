import Foundation

/// Runs `omp usage --json` and returns stdout.
actor OmpClient {
    var ompPath: String
    var timeoutSeconds: TimeInterval
    var maxBytes: Int

    init(
        ompPath: String = "omp",
        timeoutSeconds: TimeInterval = 30,
        maxBytes: Int = 262_144
    ) {
        self.ompPath = ompPath
        self.timeoutSeconds = timeoutSeconds
        self.maxBytes = maxBytes
    }

    func fetchUsageJSON() async throws -> String {
        let resolved = resolveOmpPath(ompPath)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolved)
        process.arguments = ["usage", "--json"]
        process.environment = augmentedEnvironment()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        _ = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutTask.cancel()

        if outData.count > maxBytes {
            throw OmpError.overflow
        }
        if process.terminationStatus != 0 {
            throw OmpError.exitCode(process.terminationStatus)
        }
        guard let text = String(data: outData, encoding: .utf8) else {
            throw OmpError.invalidUTF8
        }
        return text
    }

    /// Prefer an absolute path; otherwise search common install locations + PATH.
    private func resolveOmpPath(_ name: String) -> String {
        if name.hasPrefix("/") {
            return name
        }
        let candidates = [
            "/opt/homebrew/bin/omp",
            "/usr/local/bin/omp",
            NSHomeDirectory() + "/.local/bin/omp",
            NSHomeDirectory() + "/.bun/bin/omp",
            NSHomeDirectory() + "/.omp/bin/omp",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if let fromPath = which(name) {
            return fromPath
        }
        return name
    }

    private func which(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.environment = augmentedEnvironment()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0,
                  let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty
            else {
                return nil
            }
            return path
        } catch {
            return nil
        }
    }

    private func augmentedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extras = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            NSHomeDirectory() + "/.local/bin",
            NSHomeDirectory() + "/.bun/bin",
            NSHomeDirectory() + "/.omp/bin",
        ]
        let path = env["PATH"] ?? ""
        let parts = (extras + path.split(separator: ":").map(String.init))
        env["PATH"] = Array(NSOrderedSet(array: parts)).compactMap { $0 as? String }.joined(separator: ":")
        return env
    }

    enum OmpError: LocalizedError {
        case overflow
        case exitCode(Int32)
        case invalidUTF8
        case notFound

        var errorDescription: String? {
            switch self {
            case .overflow:
                return "omp usage output exceeded size limit."
            case .exitCode(let code):
                return "omp usage exited with code \(code)."
            case .invalidUTF8:
                return "omp usage returned non-UTF8 output."
            case .notFound:
                return "omp not found on PATH. Install Oh My Pi first."
            }
        }
    }
}
