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
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/STTextView", from: "2.2.0")
    ],
    targets: [
        .target(
            name: "RecordInBarKit",
            dependencies: [
                .product(name: "STTextView", package: "STTextView")
            ]
        ),
        .testTarget(
            name: "RecordInBarKitTests",
            dependencies: ["RecordInBarKit"],
            path: "Tests/RecordInBarKitTests"
        )
    ]
)
