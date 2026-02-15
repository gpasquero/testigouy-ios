// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Claudio",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ClaudioLib", targets: ["ClaudioLib"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ClaudioLib",
            dependencies: [],
            path: "Claudio",
            exclude: [
                "Resources/Info.plist",
                "Resources/Assets.xcassets",
                "Services/Persistence/Claudio.xcdatamodeld",
                "App/ClaudioApp.swift",
            ]
        ),
    ]
)
