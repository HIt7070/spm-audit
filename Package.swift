// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "spm-audit",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "spm-audit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "spm-audit-tests",
            dependencies: [
                "spm-audit",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "spm-audit-tests/Fixtures",
            resources: [
                .copy("exactVersion"),
                .copy("upToNextMajorVersion"),
                .copy("upToNextMinorVersion"),
                .copy("versionRange")
            ]
        )
    ]
)
