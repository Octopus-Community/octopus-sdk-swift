// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OctopusSdkSwift",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "OctopusUI",
            targets: ["OctopusUI"]),
        .library(
            name: "Octopus",
            targets: ["Octopus"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMajor(from: "1.20.0")),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "OctopusUI",
            dependencies: [
                "Octopus",
                "OctopusCore",
            ]),
        .target(
            name: "Octopus",
            dependencies: [
                "OctopusCore",
                "DependencyInjection",
            ]),
        .target(
            name: "OctopusCore",
            dependencies: [
                "RemoteClient",
                "KeychainAccess",
                "GrpcModels",
                "DependencyInjection"
            ],
            resources: [
                .copy("Persistence/Database/OctopusModel.xcdatamodeld"),
            ]),
        .target(
            name: "RemoteClient",
            dependencies: [
                "GrpcModels"
            ]
        ),
        .target(
            name: "GrpcModels",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "GRPC", package: "grpc-swift"),
            ],
            exclude: ["ProtoFiles"]),
        .target(
            name: "DependencyInjection"
        ),
        .testTarget(
            name: "OctopusUITests",
            dependencies: [
                "OctopusUI",
                "Octopus",
            ]
        ),
        .testTarget(
            name: "OctopusTests",
            dependencies: [
                "Octopus",
            ]
        ),
        .testTarget(
            name: "OctopusCoreTests",
            dependencies: [
                "OctopusCore",
            ]
        ),
        .testTarget(
            name: "DependencyInjectionTests",
            dependencies: ["DependencyInjection"]
        )
    ]
)
