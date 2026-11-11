// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QSnip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "qsnip", targets: ["QSnip"])
    ],
    targets: [
        .executableTarget(
            name: "QSnip",
            path: "Sources"
        ),
        .testTarget(
            name: "QSnipTests",
            dependencies: ["QSnip"],
            path: "Tests/QSnipTests"
        )
    ]
)
