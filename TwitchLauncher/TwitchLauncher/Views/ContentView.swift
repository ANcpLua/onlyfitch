import SwiftUI

// MARK: - Main App View

struct ContentView: View {
    @Environment(StreamViewModel.self) private var viewModel
    @State private var searchText = ""

    var body: some View {
        ZStack {
            // Rich gradient background for glass refraction
            AnimatedMeshBackground()
                .ignoresSafeArea()

            if !viewModel.hasValidConfig {
                SetupPromptView()
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Live Streams
                            if !liveStreams.isEmpty {
                                StreamGridSection(
                                    title: "Live Now",
                                    count: liveStreams.count,
                                    streams: liveStreams
                                )
                            }

                            // Offline Channels
                            if !offlineStreams.isEmpty {
                                OfflineSection(streams: offlineStreams)
                            }
                        }
                        .padding(20)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .navigationTitle("Streams")
                    .searchable(text: $searchText, prompt: "Search channels...")
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                Task { await viewModel.refresh() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .disabled(viewModel.isLoading)

                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else if let lastRefresh = viewModel.lastRefresh {
                                Text(lastRefresh, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            SettingsLink {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.startAutoRefresh() }
        .onDisappear { viewModel.stopAutoRefresh() }
    }

    private var liveStreams: [StreamInfo] {
        viewModel.streams
            .filter(\.isOnline)
            .filter { searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) || $0.gameName.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.viewerCount > $1.viewerCount }
    }

    private var offlineStreams: [StreamInfo] {
        viewModel.streams
            .filter { !$0.isOnline }
            .filter { searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Stream Grid Section

struct StreamGridSection: View {
    let title: String
    let count: Int
    let streams: [StreamInfo]

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text("\(count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.15), in: Capsule())
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(streams) { stream in
                    StreamCard(stream: stream)
                }
            }
        }
    }
}

// MARK: - Stream Card with Thumbnail

struct StreamCard: View {
    let stream: StreamInfo
    @State private var isHovered = false
    @State private var launchError: String?

    var body: some View {
        Button {
            launch()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail
                ZStack(alignment: .topLeading) {
                    // Cached thumbnail image
                    CachedAsyncImage(url: stream.thumbnailURL(width: 440, height: 248)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        thumbnailPlaceholder
                    }
                    .frame(height: 140)
                    .clipped()

                    // LIVE badge
                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.red, in: RoundedRectangle(cornerRadius: 4))
                        .padding(8)
                }

                // Info section
                HStack(spacing: 10) {
                    // Avatar
                    AvatarCircle(stream: stream)

                    // Channel info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stream.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(stream.gameName.isEmpty ? "Just Chatting" : stream.gameName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Viewer count
                    HStack(spacing: 3) {
                        Image(systemName: "eye")
                            .font(.caption2)
                        Text(stream.formattedViewers)
                            .font(.caption.weight(.medium).monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1)
        .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
        .animation(.spring(duration: 0.25, bounce: 0.4), value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityLabel(stream.accessibilityDescription)
        .alert("Launch Error", isPresented: .init(
            get: { launchError != nil },
            set: { if !$0 { launchError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchError ?? "")
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.1, blue: 0.25),
                        Color(red: 0.1, green: 0.08, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16/9, contentMode: .fill)
            .overlay {
                Image(systemName: "tv")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.2))
            }
    }

    private func launch() {
        Task {
            do {
                try await StreamLauncher.launch(channel: stream.name)
            } catch let error as StreamLauncher.LaunchError {
                // Only show alert for real errors, not rate limiting
                if case .rateLimited = error {
                    return // Silent ignore
                }
                launchError = error.localizedDescription
            } catch {
                launchError = error.localizedDescription
            }
        }
    }
}

// MARK: - Avatar Circle

struct AvatarCircle: View {
    let stream: StreamInfo

    var body: some View {
        let c = stream.avatarColor.color
        Circle()
            .fill(Color(red: c.r, green: c.g, blue: c.b))
            .frame(width: 32, height: 32)
            .overlay {
                Text(stream.initial)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Offline Section

struct OfflineSection: View {
    let streams: [StreamInfo]

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Offline")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(streams) { stream in
                    OfflineCard(stream: stream)
                }
            }
        }
    }
}

// MARK: - Offline Card

struct OfflineCard: View {
    let stream: StreamInfo
    @State private var isHovered = false
    @State private var launchError: String?

    var body: some View {
        Button {
            launch()
        } label: {
            VStack(spacing: 8) {
                // Placeholder thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "tv")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.15))
                    }

                // Info
                HStack(spacing: 8) {
                    AvatarCircle(stream: stream)
                        .scaleEffect(0.8)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(stream.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("Offline")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
            }
            .padding(8)
            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .opacity(0.6)
        .scaleEffect(isHovered ? 1.03 : 1)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .alert("Stream Offline", isPresented: .init(
            get: { launchError != nil },
            set: { if !$0 { launchError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchError ?? "")
        }
    }

    private func launch() {
        Task {
            do {
                try await StreamLauncher.launch(channel: stream.name)
            } catch let error as StreamLauncher.LaunchError {
                if case .rateLimited = error {
                    return // Silent ignore
                }
                launchError = error.localizedDescription
            } catch {
                launchError = error.localizedDescription
            }
        }
    }
}

// MARK: - Static Mesh Background (CPU efficient)

struct AnimatedMeshBackground: View {
    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                // Deep purple gradient - static
                Color(red: 0.10, green: 0.06, blue: 0.18),
                Color(red: 0.18, green: 0.10, blue: 0.28),
                Color(red: 0.08, green: 0.06, blue: 0.16),

                Color(red: 0.14, green: 0.10, blue: 0.24),
                Color(red: 0.30, green: 0.16, blue: 0.45), // Twitch purple center
                Color(red: 0.12, green: 0.14, blue: 0.26),

                Color(red: 0.05, green: 0.04, blue: 0.10),
                Color(red: 0.08, green: 0.06, blue: 0.14),
                Color(red: 0.04, green: 0.03, blue: 0.08)
            ]
        )
    }
}

// MARK: - Setup Prompt

struct SetupPromptView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "play.tv.fill")
                .font(.system(size: 64))
                .foregroundStyle(.purple.gradient)

            VStack(spacing: 8) {
                Text("Welcome to Twitch Launcher")
                    .font(.title.weight(.semibold))

                Text("Configure your Twitch API credentials to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            SettingsLink {
                Label("Open Settings", systemImage: "gearshape.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

            VStack(spacing: 6) {
                Text("Need API credentials?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("Visit dev.twitch.tv", destination: Constants.URLs.twitchDeveloperPortal)
                    .font(.caption.weight(.medium))
            }

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(StreamViewModel())
        .frame(width: 1000, height: 800)
}
