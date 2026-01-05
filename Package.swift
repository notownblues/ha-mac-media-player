// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacMediaPlayer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacMediaPlayer", targets: ["MacMediaPlayer"])
    ],
    dependencies: [
        .package(url: "https://github.com/emqx/CocoaMQTT.git", from: "2.1.0"),
        .package(url: "https://github.com/InerziaSoft/ISSoundAdditions.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MacMediaPlayer",
            dependencies: [
                "CocoaMQTT",
                "ISSoundAdditions"
            ],
            path: "MacMediaPlayer",
            exclude: ["App/Info.plist"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
