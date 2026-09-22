// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "MixinServices",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MixinServices", type: .static, targets: ["MixinServices"]),
        .library(name: "TIP", targets: ["TIP"]),
        .library(name: "XKCP_FIPS202", targets: ["XKCP_FIPS202"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Alamofire/Alamofire.git",
            "5.11.2"..<"999.0.0",
        ),
        .package(
            url: "https://github.com/bugsnag/bugsnag-cocoa.git",
            "6.36.0"..<"999.0.0",
        ),
        .package(
            url: "https://github.com/groue/GRDB.swift.git",
            "6.29.3"..<"999.0.0",
        ),
        .package(
            url: "https://github.com/SDWebImage/SDWebImage.git",
            "5.21.7"..<"999.0.0",
        ),
        .package(
            url: "https://github.com/jedisct1/swift-sodium.git",
            "0.9.1"..<"999.0.0",
        ),
        .package(
            url: "https://github.com/marmelroy/Zip.git",
            "2.1.2"..<"999.0.0",
        ),
        .package(
            url: "https://github.com/MixinNetwork/libsignal-protocol-c.git",
            branch: "master",
        ),
    ],
    targets: [
        .binaryTarget(name: "TIP", path: "MixinServices/TIP.xcframework"),
        .binaryTarget(name: "XKCP_FIPS202", path: "MixinServices/XKCP_FIPS202.xcframework"),
        .target(
            name: "CMixinServices",
            dependencies: [
                .product(name: "libsignal-protocol-c", package: "libsignal-protocol-c"),
            ],
            path: "MixinServices",
            sources: [
                "Crypto/Argon2",
                "Database/Function/uuidtoken.c",
                "Foundation/Markdown",
                "Services/libsignal-protocol-swift/Setup/crypto_provider.c",
                "Services/libsignal-protocol-swift/Setup/setup.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("Crypto/Argon2/include"),
                .headerSearchPath("Foundation/Markdown/md4c"),
            ],
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("Security"),
                .linkedLibrary("c++"),
            ],
        ),
        .target(
            name: "MixinServices",
            dependencies: [
                "CMixinServices",
                "TIP",
                "XKCP_FIPS202",
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "Bugsnag", package: "bugsnag-cocoa"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "Sodium", package: "swift-sodium"),
                .product(name: "Zip", package: "Zip"),
                .product(name: "libsignal-protocol-c", package: "libsignal-protocol-c"),
            ],
            path: "MixinServices",
            exclude: [
                "Crypto/Argon2",
                "Database/Function/uuidtoken.c",
                "Database/Function/uuidtoken.h",
                "Foundation/Markdown",
                "Services/libsignal-protocol-swift/Setup/crypto_provider.c",
                "Services/libsignal-protocol-swift/Setup/setup.c",
                "Services/libsignal-protocol-swift/Setup/setup.h",
            ],
            sources: ["Foundation", "Crypto", "Database", "Services"],
            swiftSettings: [.define("SQLITE_ENABLE_FTS5")],
        ),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14,
)
