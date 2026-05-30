import SwiftUI

struct ProcessingView: View {
    let progress: ProcessingProgress

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 8) {
                Text(progress.label)
                    .font(Theme.headingFont)
                    .foregroundStyle(Theme.ink)
                if let file = progress.currentFile {
                    Text(file)
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            progressBar
                .padding(.horizontal, 60)
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    @ViewBuilder
    private var progressBar: some View {
        if progress.isDeterminate {
            VStack(spacing: 6) {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .tint(Theme.ink)
                HStack {
                    Spacer()
                    Text("\(Int(progress.fraction * 100))%")
                        .font(Theme.smallFont)
                        .foregroundStyle(Theme.muted)
                }
            }
        } else {
            ProgressView()
                .progressViewStyle(.linear)
                .tint(Theme.ink)
        }
    }
}
