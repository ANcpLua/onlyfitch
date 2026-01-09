import Foundation

enum TwitchAPIError: LocalizedError {
    case invalidCredentials
    case rateLimited(retryAfter: Int)
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse(Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid API credentials. Check config.json."
        case .rateLimited(let seconds):
            return "Rate limited. Retry in \(seconds)s."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .invalidResponse(let code):
            return "HTTP \(code)"
        case .invalidURL:
            return "Invalid API URL"
        }
    }
}

actor TwitchAPI {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let maxRetries = 3
    private let baseRetryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchStreams(channels: [String], clientId: String, accessToken: String) async throws -> [StreamInfo] {
        guard !clientId.isEmpty, !accessToken.isEmpty else {
            throw TwitchAPIError.invalidCredentials
        }

        var allStreams: [StreamInfo] = []
        let channelMap = Dictionary(uniqueKeysWithValues: channels.map { ($0.lowercased(), $0) })

        // Batch requests (Twitch max 100 per request)
        for batch in channels.chunked(into: 100) {
            let streams = try await fetchStreamBatchWithRetry(
                channels: batch,
                clientId: clientId,
                accessToken: accessToken
            )
            allStreams.append(contentsOf: streams)
        }

        // Create offline entries for channels not in response
        let onlineNames = Set(allStreams.map { $0.name.lowercased() })
        let offlineStreams = channels
            .filter { !onlineNames.contains($0.lowercased()) }
            .map { StreamInfo(name: channelMap[$0.lowercased()] ?? $0) }

        return allStreams + offlineStreams
    }

    /// Fetch with exponential backoff retry on rate limit
    private func fetchStreamBatchWithRetry(
        channels: [String],
        clientId: String,
        accessToken: String
    ) async throws -> [StreamInfo] {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await fetchStreamBatch(
                    channels: channels,
                    clientId: clientId,
                    accessToken: accessToken
                )
            } catch TwitchAPIError.rateLimited(let retryAfter) {
                lastError = TwitchAPIError.rateLimited(retryAfter: retryAfter)

                // Use server-provided delay or exponential backoff
                let delay = retryAfter > 0 ? UInt64(retryAfter) * 1_000_000_000 : baseRetryDelay * UInt64(1 << attempt)
                try await Task.sleep(nanoseconds: delay)
            } catch {
                throw error // Non-retryable errors
            }
        }

        throw lastError ?? TwitchAPIError.networkError(URLError(.timedOut))
    }

    private func fetchStreamBatch(
        channels: [String],
        clientId: String,
        accessToken: String
    ) async throws -> [StreamInfo] {
        guard var components = URLComponents(string: "https://api.twitch.tv/helix/streams") else {
            throw TwitchAPIError.invalidURL
        }
        components.queryItems = channels.map { URLQueryItem(name: "user_login", value: $0) }

        guard let url = components.url else {
            throw TwitchAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(clientId, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwitchAPIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw TwitchAPIError.invalidCredentials
        case 429:
            // Ratelimit-Reset is a Unix epoch timestamp, NOT seconds remaining
            // Calculate actual seconds to wait
            let resetTimestamp = Double(httpResponse.value(forHTTPHeaderField: "Ratelimit-Reset") ?? "0") ?? 0
            let currentTime = Date().timeIntervalSince1970
            let retryAfter = max(1, Int(resetTimestamp - currentTime))
            throw TwitchAPIError.rateLimited(retryAfter: retryAfter)
        default:
            throw TwitchAPIError.invalidResponse(httpResponse.statusCode)
        }

        let apiResponse = try decoder.decode(TwitchStreamResponse.self, from: data)

        return apiResponse.data.map { stream in
            StreamInfo(
                name: stream.userLogin,
                displayName: stream.userName,
                isOnline: true,
                viewerCount: stream.viewerCount,
                gameName: stream.gameName,
                title: stream.title,
                thumbnailUrl: stream.thumbnailUrl
            )
        }
    }
}

// MARK: - API Response Models

private struct TwitchStreamResponse: Decodable {
    let data: [TwitchStream]
}

private struct TwitchStream: Decodable {
    let userLogin: String
    let userName: String
    let viewerCount: Int
    let gameName: String
    let title: String
    let thumbnailUrl: String
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
