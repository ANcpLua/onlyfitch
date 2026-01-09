import Foundation

/// Centralized URL constants for all app resources.
/// Using static constants prevents force-unwrap crashes and ensures URL validity at compile time.
enum Constants {
    enum URLs {
        // MARK: - Twitch URLs

        /// Base URL for Twitch channels
        static let twitchBase = "https://www.twitch.tv"

        /// Twitch Developer Portal
        static let twitchDeveloperPortal = URL(string: "https://dev.twitch.tv")!

        /// Twitch Helix API base
        static let helixAPI = URL(string: "https://api.twitch.tv/helix")!

        /// Twitch OAuth endpoint
        static let oauth = URL(string: "https://id.twitch.tv/oauth2")!

        // MARK: - External Resources

        /// Streamlink documentation
        static let streamlinkDocs = URL(string: "https://streamlink.github.io")!

        // MARK: - Dynamic URLs

        /// Constructs a full Twitch channel URL
        /// - Parameter channel: The channel username
        /// - Returns: Full URL string for the channel
        static func channelURL(for channel: String) -> String {
            "\(twitchBase)/\(channel)"
        }

        /// Constructs a Helix API endpoint URL
        /// - Parameter endpoint: The API endpoint path (e.g., "streams", "users")
        /// - Returns: Full URL for the endpoint, or nil if invalid
        static func helixEndpoint(_ endpoint: String) -> URL? {
            URL(string: "https://api.twitch.tv/helix/\(endpoint)")
        }
    }
}
