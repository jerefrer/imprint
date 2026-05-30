import SwiftUI
import AppKit

struct SummaryView: View {
    let summary: ProcessSummary
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Headline
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.success)
                Text("Done")
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.ink)
                Text("\(summary.updatedCount) \(summary.updatedCount > 1 ? "photos imprinted" : "photo imprinted") in **\(summary.folder.lastPathComponent)**")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            // Stats
            HStack(spacing: 24) {
                StatPill(icon: "checkmark.circle.fill", count: summary.stampedCount,
                         label: "imprinted",
                         color: Theme.success)
                if summary.noCaptionCount > 0 {
                    StatPill(icon: "questionmark.circle.fill", count: summary.noCaptionCount,
                             label: "no caption",
                             color: Theme.warning)
                }
                if summary.missingFileCount > 0 {
                    StatPill(icon: "exclamationmark.triangle.fill", count: summary.missingFileCount,
                             label: "no photo",
                             color: Theme.warning)
                }
            }
            .padding(.bottom, 18)

            // File list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(summary.files) { file in
                        FileRow(file: file)
                        if file.id != summary.files.last?.id {
                            Divider().background(Theme.paperDeep.opacity(0.5))
                        }
                    }
                }
                .background(Theme.paper.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.paperDeep, lineWidth: 1)
                )
            }
            .padding(.horizontal, 28)

            // Actions
            HStack(spacing: 12) {
                Button(action: openFolder) {
                    Label("Open folder", systemImage: "folder")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                Button(action: onReset) {
                    Label("Imprint another folder", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
    }

    private func openFolder() {
        NSWorkspace.shared.open(summary.folder)
    }
}

// MARK: - Stat pill

private struct StatPill: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.paper.opacity(0.7))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.paperDeep, lineWidth: 1))
    }
}

// MARK: - File row

private struct FileRow: View {
    let file: FileResult

    var body: some View {
        HStack(spacing: 14) {
            statusIcon
                .frame(width: 18)
            Text(file.filename)
                .font(Theme.monoFont)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 160, alignment: .leading)
            Text(captionDisplay)
                .font(.system(size: 12))
                .foregroundStyle(file.caption == nil ? Theme.muted : Theme.inkSoft)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(statusLabel)
                .font(Theme.smallFont)
                .foregroundStyle(statusColor)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch file.status {
        case .stamped:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
        case .noCaption:
            Image(systemName: "questionmark.circle").foregroundStyle(Theme.warning)
        case .missingFile:
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.warning)
        }
    }

    private var statusLabel: String {
        switch file.status {
        case .stamped:     return "imprinted"
        case .noCaption:   return "no caption"
        case .missingFile: return "no photo"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .stamped:                  return Theme.muted
        case .noCaption, .missingFile:  return Theme.warning
        }
    }

    private var captionDisplay: String {
        guard let raw = file.caption?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return "—" }
        // Aplatit les sauts de ligne pour rester sur une seule ligne
        return raw.replacingOccurrences(of: "\n", with: " ")
                  .replacingOccurrences(of: "\r", with: " ")
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(Theme.paper)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(Theme.ink)
            .background(configuration.isPressed ? Theme.paperDeep : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
