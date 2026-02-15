// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestigoUY",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "TestigoUYLib", targets: ["TestigoUYLib"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "TestigoUYLib",
            dependencies: [],
            path: "TestigoUY",
            exclude: [
                "Resources/Info.plist",
                "Resources/Assets.xcassets",
                "Services/Persistence/TestigoUY.xcdatamodeld",
                "App/TestigoUYApp.swift",
            ]
        ),
    ]
)
