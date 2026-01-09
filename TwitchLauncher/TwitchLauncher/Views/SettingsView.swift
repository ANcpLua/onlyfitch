import SwiftUI

struct SettingsView: View {
    @Environment(StreamViewModel.self) private var viewModel
    @State private var selectedTab: SettingsTab = .api
    @State private var channelsText = ""
    @State private var showingImportAlert = false
    @State private var importedCount = 0

    var body: some View {
        @Bindable var vm = viewModel

        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.06, green: 0.05, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                // MARK: - API Tab
                Tab("API", systemImage: "key.fill", value: .api) {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Credentials Card
                            GlassSettingsCard(title: "Twitch API Credentials", icon: "lock.shield.fill") {
                                VStack(spacing: 16) {
                                    GlassTextField(
                                        title: "Client ID",
                                        text: $vm.config.clientId,
                                        placeholder: "Your Twitch Client ID"
                                    )

                                    GlassSecureField(
                                        title: "Access Token",
                                        text: $vm.config.accessToken,
                                        placeholder: "Your Access Token"
                                    )
                                }
                            }

                            // Help Link
                            Link(destination: Constants.URLs.twitchDeveloperPortal) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("Get credentials at dev.twitch.tv")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(16)
                            }
                            .buttonStyle(.glass)

                            // Refresh Interval
                            GlassSettingsCard(title: "Refresh Interval", icon: "clock.fill") {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("\(vm.config.refreshInterval) seconds")
                                            .font(.title2.weight(.semibold).monospacedDigit())
                                        Spacer()
                                    }

                                    Slider(
                                        value: .init(
                                            get: { Double(vm.config.refreshInterval) },
                                            set: { vm.config.refreshInterval = Int($0) }
                                        ),
                                        in: 30...300,
                                        step: 10
                                    )
                                    .tint(.purple)

                                    HStack {
                                        Text("30s")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Text("5min")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .padding(24)
                    }
                }

                // MARK: - Channels Tab
                Tab("Channels", systemImage: "list.bullet", value: .channels) {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Followed Channels")
                                    .font(.title3.weight(.semibold))
                                Text("\(vm.config.channels.count) channels")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                importFromPython()
                            } label: {
                                Label("Import Default", systemImage: "square.and.arrow.down")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(20)

                        // Editor
                        TextEditor(text: $channelsText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial.opacity(0.5))
                            }
                            .padding(.horizontal, 20)

                        // Footer
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.tertiary)
                            Text("One channel per line")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .padding(20)
                    }
                }

                // MARK: - About Tab
                Tab("About", systemImage: "info.circle.fill", value: .about) {
                    VStack(spacing: 32) {
                        Spacer()

                        // App Icon
                        ZStack {
                            Circle()
                                .fill(.purple.gradient.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)

                            Image(systemName: "play.tv.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.purple.gradient)
                        }

                        VStack(spacing: 8) {
                            Text("Twitch Launcher")
                                .font(.title.weight(.bold))

                            Text("SwiftUI + Liquid Glass")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("macOS 26 • iOS 26 Design System")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        // Links
                        VStack(spacing: 12) {
                            Link(destination: Constants.URLs.twitchDeveloperPortal) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Twitch Developer Portal")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .padding(14)
                            }
                            .buttonStyle(.glass)

                            Link(destination: Constants.URLs.streamlinkDocs) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Streamlink Documentation")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .padding(14)
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(.horizontal, 40)

                        Spacer()

                        // Config path
                        VStack(spacing: 4) {
                            Text("Config Location")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("~/.config/twitch-launcher/config.json")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.quaternary)
                                .textSelection(.enabled)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
        .frame(width: 500, height: 450)
        .onAppear {
            channelsText = vm.config.channels.joined(separator: "\n")
        }
        .onDisappear {
            saveChanges()
        }
        .onChange(of: channelsText) {
            vm.config.channels = channelsText
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        .alert("Channels Imported", isPresented: $showingImportAlert) {
            Button("OK") {}
        } message: {
            Text("Imported \(importedCount) channels")
        }
    }

    private func saveChanges() {
        viewModel.saveConfig()
        Task {
            await viewModel.refresh()
        }
    }

    private func importFromPython() {
        let pythonChannels = [
            "ScripeScripe", "metashi12", "Fanasia", "fearlessdumb0", "vickmantwo",
            "CubeTTV_", "waalpen", "MAGEFISTpoe", "snoobae85", "Naguura",
            "ohnePixel", "Goratha", "ortemismw", "Grubby", "captainviruz",
            "KireiLoL", "SilphiTv", "Rekkles", "Tolkin", "GamesDoneQuick",
            "agurin", "Ventrua", "Thebausffs", "Frodan", "DonaldTrump",
            "NoWay4u_Sir", "yingyangyu", "Thdlock", "turdtwisterx", "lytylisius",
            "emiracles", "redviles", "Palsteron", "cArn_", "jungroan",
            "TriPolarBear", "Pohx", "TeamfightTactics", "MontanaBlack88", "Naturensoehne",
            "Caedrel", "L0ganJG", "CuteDog_", "b3nyo", "MusclebrahTV",
            "yamatosdeath", "captainlance9", "fubgun", "Darki5683", "Ruetoo",
            "Subtractem", "tytykiller", "TeamLiquid", "Blizzard", "GhazzyTV",
            "Koshde", "crouching_tuna", "spicysushi_poe", "players_hub", "senfiowl",
            "zackrawrr", "Shurjoka", "Rezo", "Sologesang", "freiraumreh",
            "KeshaEuw", "LEC", "Doctorio", "skittlerNS", "riotgames",
            "Doublelift", "ElbroTTV", "roafim", "ZugraTV", "HYP3RSOMNIAC",
            "snapow", "pathofexile", "uiNico", "Neevi", "Erinalis",
            "HealthyGamer_GG", "Kib0", "Zizaran", "sweeneytv_", "Fehhlo",
            "Lipperino", "s1qs", "Nyhxy", "THE_CRONIX", "madmike577",
            "Flow_G", "LCS", "CasiePoE", "SosoPinkPally", "Mithauw",
            "camuel01", "cdprojektred", "Teggu", "KafkaShrimp", "TheGAM3Report",
            "Empyriangaming", "exomni", "JesibuGaming", "Dezpyer", "PiecesGG",
            "qkns", "Foresight123", "gamescom", "DJRonSwanson", "Ben_",
            "Echo_Esports", "Mystler", "rubism", "Trigadonn", "rami_rng",
            "Philwestside", "Fyndel_Poe", "yelena12321", "NASA", "FataxOW",
            "inakzeptabel_hd", "dnxz", "Asmongold", "Mathil1", "Wildigenia",
            "R3Lix", "Xuvion", "chirsen", "JustpG_", "KVitTa",
            "Quyncy", "ImJabba", "Maximum", "AversionDE", "Alari0n",
            "gerlox_", "Weedfists", "Lay0ut", "sawako07", "BobPlaysTheGames",
            "deazyy", "Rheyzn", "WoWMDI_A", "vaporlulz", "WarcraftDE",
            "Extex31", "Warcraft", "Method", "Sco", "asakawa",
            "Ashine", "Nnoggie"
        ]

        viewModel.config.channels = pythonChannels
        channelsText = pythonChannels.joined(separator: "\n")
        viewModel.saveConfig()
        importedCount = pythonChannels.count
        showingImportAlert = true
    }
}

// MARK: - Settings Tab

enum SettingsTab: Hashable {
    case api, channels, about
}

// MARK: - Glass Settings Card

struct GlassSettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.purple)
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Glass Text Field

struct GlassTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial.opacity(0.5))
                }
        }
    }
}

// MARK: - Glass Secure Field

struct GlassSecureField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(0.5))
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(StreamViewModel())
}
