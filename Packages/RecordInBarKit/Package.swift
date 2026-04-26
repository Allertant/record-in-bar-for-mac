// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecordInBarKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "RecordInBarKit", targets: ["RecordInBarKit"])
    ],
    targets: [
        .target(name: "RecordInBarKit"),
        .testTarget(
            name: "RecordInBarKitTests",
            dependencies: ["RecordInBarKit"],
            path: "Tests/RecordInBarKitTests"
        )
    ]
)
