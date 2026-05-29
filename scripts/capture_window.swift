// Affiche l'ID de la fenêtre principale d'une app par nom de processus.
// Usage : swift scripts/capture_window.swift APP_NAME
// Sortie : <window_id> sur stdout, à utiliser avec `screencapture -l <id>`

import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: swift scripts/capture_window.swift APP_NAME\n".data(using: .utf8)!)
    exit(2)
}
let appName = args[1]

let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

var targetWindowID: CGWindowID?
var maxArea: CGFloat = 0

for w in windowList {
    guard let owner = w[kCGWindowOwnerName as String] as? String,
          owner == appName else { continue }
    guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
    guard let boundsDict = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
    guard let id = w[kCGWindowNumber as String] as? CGWindowID else { continue }
    let area = (boundsDict["Width"] ?? 0) * (boundsDict["Height"] ?? 0)
    if area > maxArea {
        maxArea = area
        targetWindowID = id
    }
}

guard let winID = targetWindowID else {
    FileHandle.standardError.write("Fenêtre '\(appName)' introuvable\n".data(using: .utf8)!)
    exit(1)
}

print(winID)
