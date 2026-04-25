// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "record-in-bar-for-mac",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "RecordInBarApp"
        ),
        .testTarget(
            name: "RecordInBarAppTests",
            dependencies: ["RecordInBarApp"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
