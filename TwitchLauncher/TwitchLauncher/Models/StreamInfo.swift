import Foundation

struct StreamInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let isOnline: Bool
    let viewerCount: Int
    let gameName: String
    let title: String
    let thumbnailUrl: String?
    let profileImageUrl: String?

    init(
        name: String,
        displayName: String? = nil,
        isOnline: Bool = false,
        viewerCount: Int = 0,
        gameName: String = "",
        title: String = "",
        thumbnailUrl: String? = nil,
        profileImageUrl: String? = nil
    ) {
        self.id = name.lowercased()
        self.name = name
        self.displayName = displayName ?? name
        self.isOnline = isOnline
        self.viewerCount = viewerCount
        self.gameName = gameName
        self.title = title
        self.thumbnailUrl = thumbnailUrl
        self.profileImageUrl = profileImageUrl
    }

    /// Get thumbnail URL with specific dimensions
    func thumbnailURL(width: Int = 440, height: Int = 248) -> URL? {
        guard let template = thumbnailUrl else { return nil }
        let urlString = template
            .replacingOccurrences(of: "{width}", with: "\(width)")
            .replacingOccurrences(of: "{height}", with: "\(height)")
        return URL(string: urlString)
    }

    var formattedViewers: String {
        switch viewerCount {
        case 1_000_000...:
            return String(format: "%.1fM", Double(viewerCount) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(viewerCount) / 1_000)
        default:
            return "\(viewerCount)"
        }
    }

    /// First letter of display name for avatar
    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    /// Color based on name hash for consistent avatar colors
    var avatarColor: AvatarColor {
        let hash = abs(name.hashValue)
        let colors: [AvatarColor] = [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]
        return colors[hash % colors.count]
    }

    /// VoiceOver-friendly description of the stream
    var accessibilityDescription: String {
        if isOnline {
            let viewerText = viewerCount == 1 ? "1 viewer" : "\(formattedViewers) viewers"
            let gameText = gameName.isEmpty ? "streaming" : "playing \(gameName)"
            return "\(displayName), live, \(gameText), \(viewerText)"
        } else {
            return "\(displayName), offline"
        }
    }
}

enum AvatarColor {
    case red, orange, yellow, green, teal, blue, purple, pink

    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .red: return (0.9, 0.3, 0.3)
        case .orange: return (0.95, 0.6, 0.2)
        case .yellow: return (0.95, 0.85, 0.3)
        case .green: return (0.3, 0.8, 0.5)
        case .teal: return (0.2, 0.75, 0.8)
        case .blue: return (0.3, 0.5, 0.95)
        case .purple: return (0.6, 0.4, 0.9)
        case .pink: return (0.9, 0.4, 0.7)
        }
    }
}
