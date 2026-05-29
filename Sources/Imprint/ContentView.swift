import SwiftUI

struct ContentView: View {
    @StateObject private var engine = ImprintEngine()

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
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
        .frame(minWidth: 580, minHeight: 540)
    }
}
