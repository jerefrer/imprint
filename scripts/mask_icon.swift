// Génère un PNG transparent avec masque squircle (style Apple, .continuous)
// à partir d'une image source (typiquement le JPG 1024×1024 généré par IA).
//
// Usage : swift scripts/mask_icon.swift INPUT OUTPUT [SIZE]
// Défaut : SIZE = 1024
//
// Le clipShape utilise RoundedRectangle .continuous via ImageRenderer (macOS 13+)
// pour obtenir un vrai squircle Apple, pas un simple coin arrondi.

import SwiftUI
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: swift scripts/mask_icon.swift INPUT OUTPUT [SIZE]\n".data(using: .utf8)!)
    exit(2)
}

let inputPath = args[1]
let outputPath = args[2]
let size: CGFloat = CGFloat(args.count >= 4 ? (Int(args[3]) ?? 1024) : 1024)

guard let sourceImage = NSImage(contentsOfFile: inputPath) else {
    FileHandle.standardError.write("Cannot load \(inputPath)\n".data(using: .utf8)!)
    exit(1)
}

@MainActor
func render() -> Data? {
    let view = Image(nsImage: sourceImage)
        .resizable()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    renderer.proposedSize = ProposedViewSize(width: size, height: size)

    guard let cgImage = renderer.cgImage else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])
}

let data = MainActor.assumeIsolated { render() }
guard let pngData = data else {
    FileHandle.standardError.write("Cannot render PNG\n".data(using: .utf8)!)
    exit(1)
}

let outURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
try pngData.write(to: outURL)
print("OK: \(outputPath) (\(pngData.count) bytes)")
