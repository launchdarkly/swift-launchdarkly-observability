// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-launchdarkly-observability",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "LaunchDarklyObservability",
            targets: ["LaunchDarklyObservability"]),
        .library(
            name: "LaunchDarklySessionReplay",
            targets: ["LaunchDarklySessionReplay"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", exact: "2.3.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", exact: "10.1.0"),
        .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.32.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
    ],
    targets: [
        // C target (no Swift files here)
        .target(
            name: "ObjCBridge",
            publicHeadersPath: "."
        ),
        .target(name: "Common",
                dependencies: [.product(name: "LaunchDarkly", package: "ios-client-sdk", condition: .when(platforms: [.iOS, .tvOS]))]),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "Common",
                "ObjCBridge",
                "URLSessionInstrumentation",
                "OpenTelemetryProtocolExporterCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "Installations", package: "KSCrash", condition: .when(platforms: [.iOS, .tvOS])),
            ]
        ),
        .testTarget(
            name: "ObservabilityTests",
            dependencies: [
                "LaunchDarklyObservability"
            ]
        ),
        .target(
            name: "LaunchDarklySessionReplay",
            dependencies: [
                "Common",
                "LaunchDarklyObservability",
            ],
        ),
        .target(
          name: "OpenTelemetryProtocolExporterCommon",
          dependencies: [
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "SwiftProtobuf", package: "swift-protobuf")
          ],
          path: "Sources/OpenTelemetry/OpenTelemetryProtocolExporterCommon"
        ),
        .target(
              name: "URLSessionInstrumentation",
              dependencies: [
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
                "NetworkStatus"],
              path: "Sources/OpenTelemetry/Instrumentation/URLSession",
              exclude: ["README.md"]
        ),
        .target(
              name: "NetworkStatus",
              dependencies: [
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
              ],
              path: "Sources/OpenTelemetry/Instrumentation/NetworkStatus",
              linkerSettings: [.linkedFramework("CoreTelephony", .when(platforms: [.iOS]))]
        ),
        .testTarget(
            name: "CommonTests",
            dependencies: [
                "Common"
            ],
            resources: [.process("GraphQL/Queries")]
        ),
        .testTarget(
            name: "SessionReplayTests",
            dependencies: [
                "LaunchDarklySessionReplay",
                "LaunchDarklyObservability"
            ]
        ),
    ]
)
