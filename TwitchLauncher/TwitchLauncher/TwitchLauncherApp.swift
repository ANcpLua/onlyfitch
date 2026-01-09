import SwiftUI

@main
struct TwitchLauncherApp: App {
    @State private var viewModel = StreamViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 800)
        .commands {
            // Remove default "New" menu item
            CommandGroup(replacing: .newItem) {}

            // Add refresh command
            CommandGroup(after: .toolbar) {
                Button("Refresh Streams") {
                    Task { await viewModel.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Clear Search") {
                    // This would need to be wired up via viewModel if needed
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }

        Settings {
            SettingsView()
                .environment(viewModel)
        }
    }
}
