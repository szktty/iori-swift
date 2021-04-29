// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Iori",
    platforms: [
        .macOS(.v10_12), .iOS(.v10),
    ],
    products: [
        .executable(
            name: "iori",
            targets: ["tool"]),
        .library(
            name: "Iori",
            targets: ["Iori"]),
    ],
    dependencies: [
        .package(
            name: "Swifter",
                 url: "https://github.com/httpswift/swifter.git", .upToNextMajor(from: "1.5.0")),
        .package(
            name: "Yaml",
                    url: "https://github.com/behrang/YamlSwift.git",
                    .upToNextMajor(from: "3.4.4")),
        .package(
			name: "swift-argument-parser",
			url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "0.4.1")),
        .package(
            name: "Base32",
            url: "https://github.com/szktty/swift-clockwork-base32.git",
	    .upToNextMajor(from: "2021.1.1")),
        .package(
            name: "Puppy",
            url: "https://github.com/sushichop/Puppy.git",
	    .upToNextMajor(from: "0.1.2")),
    ],
    targets: [
        .target(name: "tool",
                dependencies: ["Iori"],
                exclude: ["Info.plist"]),
        .target(
            name: "Iori",
            dependencies: ["Swifter", "Yaml",
.product(name: "ArgumentParser", package: "swift-argument-parser")
, "Base32", "Puppy"],
            exclude: ["Info.plist"]),
    ]
)
