import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var engine = ImprintEngine()

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch engine.state {
                    case .idle:
                        DropZoneView { url in engine.start(folder: url) }
                    case .processing(let progress):
                        ProcessingView(progress: progress)
                    case .done(.success(let summary)):
                        SummaryView(summary: summary) { engine.reset() }
                    case .done(.failure(let error)):
                        ErrorView(error: error) { engine.reset() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 580, minHeight: 540)
    }

    private var header: some View {
        HStack(spacing: 12) {
            appIcon
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
            Text("Imprint")
                .font(Theme.headingFont)
                .foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Theme.paper)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.paperDeep),
            alignment: .bottom
        )
    }

    /// Charge l'icône de l'app depuis Contents/Resources/Imprint.icns
    /// (résolue via CFBundleIconFile=Imprint). Repli sur un SF Symbol si
    /// l'icône n'est pas trouvée (cas d'un dev via `swift run` sans bundle).
    private var appIcon: Image {
        if let nsImage = NSImage(named: "Imprint") {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "photo.stack.fill")
    }
}
