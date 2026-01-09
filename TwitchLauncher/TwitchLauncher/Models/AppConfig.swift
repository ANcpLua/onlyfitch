import Foundation

struct AppConfig: Codable {
    var clientId: String
    var accessToken: String
    var channels: [String]
    var refreshInterval: Int

    static let defaultConfig = AppConfig(
        clientId: "",
        accessToken: "",
        channels: [],
        refreshInterval: 60
    )

    static var configURL: URL {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("twitch-launcher")

        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        return configDir.appendingPathComponent("config.json")
    }

    static func load() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            let example = AppConfig(
                clientId: "YOUR_CLIENT_ID",
                accessToken: "YOUR_ACCESS_TOKEN",
                channels: ["Asmongold", "Zizaran", "Mathil1"],
                refreshInterval: 60
            )
            try? example.save()
            return example
        }

        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("Config load error: \(error)")
            return defaultConfig
        }
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Self.configURL, options: .atomic)
    }
}
