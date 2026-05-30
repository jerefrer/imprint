import SwiftUI

@main
struct ImprintApp: App {
    @StateObject private var updaterController = UpdaterController()

    var body: some Scene {
        Window("Imprint", id: "imprint-main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            // « Check for Updates… » est inséré dans le menu Imprint, juste
            // après « About Imprint », au-dessus de Preferences.
            CommandGroup(after: .appInfo) {
                CheckForUpdatesMenuItem(controller: updaterController)
            }
            CommandGroup(replacing: .help) {
                Link("Imprint Help", destination: URL(string: "https://github.com/jerefrer/imprint")!)
            }
        }
    }
}
