import SwiftUI

@main
struct ImprintApp: App {
    var body: some Scene {
        Window("Imprint", id: "imprint-main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Link("Imprint Help", destination: URL(string: "https://github.com/jerefrer/imprint")!)
            }
        }
    }
}
