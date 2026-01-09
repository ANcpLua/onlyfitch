import Foundation

/// Launches Twitch streams via Streamlink with rate limiting.
///
/// ## Detached Process Behavior
/// The launched streamlink process runs independently of the app:
/// - The process is **not** terminated when the app quits
/// - VLC/mpv player windows persist after TwitchLauncher closes
/// - This is intentional: users can close the launcher after starting streams
///
/// ## Rate Limiting
/// - 5 second cooldown per channel to prevent accidental double-opens
/// - Rapid clicks on the same stream are ignored
///
/// ## Requirements
/// - `streamlink` must be installed: `brew install streamlink`
/// - A compatible player (VLC, mpv) should be available
enum StreamLauncher {
    enum LaunchError: LocalizedError {
        case streamlinkNotFound
        case launchFailed(Error)
        case rateLimited // Silent - no message needed

        var errorDescription: String? {
            switch self {
            case .streamlinkNotFound:
                return "Streamlink not found. Install via: brew install streamlink"
            case .launchFailed(let error):
                return "Launch failed: \(error.localizedDescription)"
            case .rateLimited:
                return nil // Silent ignore
            }
        }
    }

    /// Track last launch time per channel
    private static var lastLaunchTimes: [String: Date] = [:]
    private static let cooldownSeconds: TimeInterval = 5

    /// Launches a Twitch stream asynchronously with rate limiting.
    ///
    /// The stream opens in streamlink's default player (usually VLC or mpv).
    /// The process runs detached and will continue even if the app closes.
    ///
    /// - Parameter channel: The Twitch channel username
    /// - Throws: `LaunchError.rateLimited` if launched recently,
    ///           `LaunchError.streamlinkNotFound` if streamlink isn't installed,
    ///           `LaunchError.launchFailed` if the process fails to start
    @MainActor
    static func launch(channel: String) async throws {
        let channelKey = channel.lowercased()

        // Check cooldown - silently ignore if too fast
        if let lastLaunch = lastLaunchTimes[channelKey] {
            let elapsed = Date().timeIntervalSince(lastLaunch)
            if elapsed < cooldownSeconds {
                throw LaunchError.rateLimited
            }
        }

        // Record launch time BEFORE launching (prevents double-clicks during launch)
        lastLaunchTimes[channelKey] = Date()

        // Find streamlink off main thread to avoid blocking UI
        let streamlinkPath = await Task.detached(priority: .userInitiated) {
            findStreamlink()
        }.value

        guard let streamlinkPath else {
            // Reset on failure so user can retry immediately
            lastLaunchTimes.removeValue(forKey: channelKey)
            throw LaunchError.streamlinkNotFound
        }

        // Launch the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: streamlinkPath)
        process.arguments = [
            Constants.URLs.channelURL(for: channel),
            "best"
        ]

        // Suppress streamlink's own output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Process is now running detached
        } catch {
            // Reset on failure so user can retry immediately
            lastLaunchTimes.removeValue(forKey: channelKey)
            throw LaunchError.launchFailed(error)
        }
    }

    private static func findStreamlink() -> String? {
        // Check PATH first
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let paths = pathEnv.split(separator: ":").map(String.init)

        for path in paths {
            let fullPath = "\(path)/streamlink"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        // Common Homebrew locations
        let commonPaths = [
            "/opt/homebrew/bin/streamlink",      // Apple Silicon
            "/usr/local/bin/streamlink",          // Intel
            "\(NSHomeDirectory())/.local/bin/streamlink",
            "/usr/bin/streamlink"
        ]

        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}
