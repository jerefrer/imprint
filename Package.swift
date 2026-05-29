// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Imprint",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Imprint",
            path: "Sources/Imprint"
        )
    ]
)
