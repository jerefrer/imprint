import SwiftUI
import Sparkle

/// Encapsule l'updater Sparkle et expose un état observable pour le menu.
/// Sparkle vérifie automatiquement la présence d'une nouvelle version au lancement
/// puis périodiquement (intervalle défini par SUScheduledCheckInterval dans
/// Info.plist). L'utilisateur peut aussi déclencher la vérification manuellement
/// via le menu « Check for Updates… ».
@MainActor
final class UpdaterController: ObservableObject {
    let updaterController: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    init() {
        // startingUpdater: true → démarre les vérifications planifiées
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Reflète l'état de l'updater dans une @Published pour activer/désactiver
        // l'item de menu pendant qu'une vérification est en cours.
        self.updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }
}

/// Item de menu « Check for Updates… » à insérer dans App.commands.
struct CheckForUpdatesMenuItem: View {
    @ObservedObject var controller: UpdaterController

    var body: some View {
        Button("Check for Updates…") {
            controller.checkForUpdates()
        }
        .disabled(!controller.canCheckForUpdates)
    }
}
