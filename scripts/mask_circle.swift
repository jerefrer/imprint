// Télécharge une image depuis une URL, la masque dans un cercle parfait
// (alpha autour), et écrit le résultat en PNG.
//
// Usage : swift scripts/mask_circle.swift INPUT_URL OUTPUT.png [SIZE]
//
// Utile pour servir un avatar rond dans un README GitHub : le markdown
// GitHub n'évalue pas les styles CSS, donc la seule manière d'avoir un
// vrai rond est d'embarquer la transparence dans le PNG lui-même.

import Foundation
import SwiftUI
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: swift scripts/mask_circle.swift INPUT_URL OUTPUT.png [SIZE]\n".data(using: .utf8)!)
    exit(2)
}
let inputURLStr = args[1]
let outputPath = args[2]
let size: CGFloat = CGFloat(args.count >= 4 ? (Int(args[3]) ?? 256) : 256)

guard let inputURL = URL(string: inputURLStr) else {
    FileHandle.standardError.write("Invalid URL\n".data(using: .utf8)!)
    exit(1)
}

let data: Data
do {
    data = try Data(contentsOf: inputURL)
} catch {
    FileHandle.standardError.write("Cannot download \(inputURLStr): \(error)\n".data(using: .utf8)!)
    exit(1)
}

guard let source = NSImage(data: data) else {
    FileHandle.standardError.write("Cannot decode image\n".data(using: .utf8)!)
    exit(1)
}

@MainActor
func render() -> Data? {
    let view = Image(nsImage: source)
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(Circle())

    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0
    renderer.proposedSize = ProposedViewSize(width: size, height: size)

    guard let cgImage = renderer.cgImage else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])
}

let pngData = MainActor.assumeIsolated { render() }
guard let bytes = pngData else {
    FileHandle.standardError.write("Cannot render PNG\n".data(using: .utf8)!)
    exit(1)
}

let outURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
try bytes.write(to: outURL)
print("OK: \(outputPath) (\(bytes.count) bytes)")
