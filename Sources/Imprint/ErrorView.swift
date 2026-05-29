import SwiftUI

struct ErrorView: View {
    let error: ImprintError
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.warning)

            VStack(spacing: 12) {
                Text("Impossible de continuer")
                    .font(Theme.headingFont)
                    .foregroundStyle(Theme.ink)
                Text(error.errorDescription ?? "Erreur inconnue")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: onReset) {
                Label("Réessayer", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
}
