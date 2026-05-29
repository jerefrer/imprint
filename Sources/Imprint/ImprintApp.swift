import SwiftUI

@main
struct ImprintApp: App {
    var body: some Scene {
        Window("Imprint", id: "imprint-main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Link("Aide Imprint", destination: URL(string: "https://github.com/jerefrer/imprint")!)
            }
        }
    }
}
