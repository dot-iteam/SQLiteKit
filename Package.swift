// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SQLiteKit",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SQLiteKit",
            targets: ["SQLiteKit"]
        ),
    ],
    dependencies: [
            .package(
                url: "https://github.com/swiftlang/swift-docc-plugin.git",
                from: "1.5.0"
            )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .systemLibrary(name: "CSQLite"),
        .target(
            name: "SQLiteKit",
            dependencies: [
                .targetItem(name: "CSQLite", condition: .when(platforms: [.linux]))
            ]
        ),
        .testTarget(
            name: "SQLiteKitTest",
            dependencies: ["SQLiteKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
