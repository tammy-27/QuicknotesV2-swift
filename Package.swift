// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "QuickNotes",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "QuickNotes",
            path: "Sources/QuickNotes"
        )
    ]
)
