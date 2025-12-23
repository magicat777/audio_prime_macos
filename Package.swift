// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioPrime",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AudioPrime",
            targets: ["AudioPrime"]
        )
    ],
    dependencies: [],
    targets: [
        // Main app target
        .executableTarget(
            name: "AudioPrime",
            dependencies: ["AudioPrimeCore"],
            path: "AudioPrime",
            resources: [.process("Resources")]
        ),

        // C++ audio processing core
        .target(
            name: "AudioPrimeCore",
            dependencies: [],
            path: "AudioPrimeCore",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .define("ACCELERATE_NEW_LAPACK"),
                .unsafeFlags(["-std=c++17"])
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("AVFoundation")
            ]
        ),

        // Test target
        .testTarget(
            name: "AudioPrimeTests",
            dependencies: ["AudioPrime", "AudioPrimeCore"],
            path: "AudioPrimeTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
