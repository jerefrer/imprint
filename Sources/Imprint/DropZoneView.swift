import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    let onFolder: (URL) -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 18) {
                Image(systemName: isHovering ? "folder.fill" : "folder")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.ink.opacity(isHovering ? 0.9 : 0.55))
                    .animation(.easeOut(duration: 0.15), value: isHovering)

                VStack(spacing: 6) {
                    Text("Drop a folder here")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.ink)
                    Text("or click to choose one")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                }

                Text("The folder must contain your .tif photos\nand an Excel or CSV file with the columns\n“Filename” and “Description”.")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 8)
            }
            .padding(48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isHovering ? Theme.paperDeep.opacity(0.6) : Theme.paper.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        Theme.ink.opacity(isHovering ? 0.65 : 0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [10, 6])
                    )
                    .animation(.easeOut(duration: 0.15), value: isHovering)
            )
            .onTapGesture { pickFolder() }
            .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                handleDrop(providers)
            }
        }
        .padding(28)
    }

    // MARK: - Folder picker

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.title = "Choose a folder"
        panel.message = "Select the folder containing your TIFF photos and the caption file."
        if panel.runModal() == .OK, let url = panel.url {
            onFolder(url)
        }
    }

    // MARK: - Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            var resolved: URL?
            if let url = item as? URL {
                resolved = url
            } else if let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) {
                resolved = url
            }
            guard let url = resolved else { return }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { return }
            DispatchQueue.main.async {
                onFolder(url)
            }
        }
        return true
    }
}
