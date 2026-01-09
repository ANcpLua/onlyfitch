import Foundation
import Observation

@Observable
@MainActor
final class StreamViewModel {
    // MARK: - State

    private(set) var streams: [StreamInfo] = []
    private(set) var isLoading = false
    private(set) var isRefreshing = false  // Background refresh indicator
    private(set) var error: String?
    private(set) var lastRefresh: Date?
    private(set) var configSaveError: String?  // Track save errors

    var searchText = ""
    var config: AppConfig

    // MARK: - Computed

    var filteredStreams: [StreamInfo] {
        let sorted = streams.sorted { lhs, rhs in
            if lhs.isOnline != rhs.isOnline {
                return lhs.isOnline
            }
            if lhs.isOnline {
                return lhs.viewerCount > rhs.viewerCount
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        guard !searchText.isEmpty else { return sorted }

        return sorted.filter { stream in
            stream.displayName.localizedCaseInsensitiveContains(searchText) ||
            stream.gameName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var onlineCount: Int {
        streams.filter(\.isOnline).count
    }

    var hasValidConfig: Bool {
        !config.clientId.isEmpty &&
        !config.accessToken.isEmpty &&
        config.clientId != "YOUR_CLIENT_ID"
    }

    // MARK: - Private

    private let api = TwitchAPI()
    private var refreshTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        self.config = AppConfig.load()
    }

    // MARK: - Actions

    func refresh() async {
        guard !isLoading else { return }
        guard hasValidConfig else {
            error = "Configure API credentials in Settings (⌘,)"
            return
        }

        // Show different loading state for background refresh vs initial load
        let isBackgroundRefresh = !streams.isEmpty
        if isBackgroundRefresh {
            isRefreshing = true
        } else {
            isLoading = true
        }
        error = nil

        do {
            streams = try await api.fetchStreams(
                channels: config.channels,
                clientId: config.clientId,
                accessToken: config.accessToken
            )
            lastRefresh = Date()
        } catch let apiError as TwitchAPIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    func startAutoRefresh() {
        stopAutoRefresh()

        refreshTask = Task { [weak self] in
            await self?.refresh()

            while !Task.isCancelled {
                // Use optional chaining throughout to avoid retain cycle
                // Don't use `guard let self` as it creates strong reference for entire scope
                guard let interval = self?.config.refreshInterval else { break }
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func saveConfig() {
        do {
            try config.save()
            configSaveError = nil
        } catch {
            configSaveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    func reloadConfig() {
        config = AppConfig.load()
    }
}
