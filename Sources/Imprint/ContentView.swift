import SwiftUI

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
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.ink)
            Text("Imprint")
                .font(Theme.headingFont)
                .foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Theme.paper)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.paperDeep),
            alignment: .bottom
        )
    }
}
