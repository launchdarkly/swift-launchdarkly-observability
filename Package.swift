// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-launchdarkly-observability",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        // OpenTelemetry pipeline only: records what the app asks it to and exports it,
        // installing no swizzles or crash handlers, so it can run beside another
        // observability SDK.
        .library(
            name: "LaunchDarklyOtel",
            targets: ["LaunchDarklyOtel"]),
        .library(
            name: "LaunchDarklyObservability",
            targets: ["LaunchDarklyObservability"]),
        .library(
            name: "LaunchDarklySessionReplay",
            targets: ["LaunchDarklySessionReplay"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", exact: "2.3.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", exact: "11.4.0-beta.1"),
        // Pinned to 2.6.0-beta.3 for iOS 26+ __crash_info parsing (so Swift
        // runtime trap messages like "Fatal error: Index out of range" are
        // captured). SwiftPM ignores pre-releases with `from:`, so pin exactly.
        .package(url: "https://github.com/kstenerud/KSCrash.git", exact: "2.6.0-beta.3"),
    ],
    targets: [
        // C target (no Swift files here)
        .target(
            name: "ObjCBridge",
            publicHeadersPath: "."
        ),
        .binaryTarget(
            name: "SessionReplayC",
            path: "Frameworks/SessionReplayC.xcframework"
        ),
        .target(name: "Common",
                dependencies: [.product(name: "LaunchDarkly", package: "ios-client-sdk", condition: .when(platforms: [.iOS, .tvOS]))]),
        .target(
            name: "LaunchDarklyOtel",
            dependencies: [
                "Common",
                "JSONExporters",
                "SDKResourceExtension",
                .product(name: "LaunchDarkly", package: "ios-client-sdk", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core", condition: .when(platforms: [.iOS, .tvOS])),
            ]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "LaunchDarklyOtel",
                "Common",
                "ObjCBridge",
                "URLSessionInstrumentation",
                "JSONExporters",
                "SDKResourceExtension",
                .product(name: "LaunchDarkly", package: "ios-client-sdk", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "Installations", package: "KSCrash", condition: .when(platforms: [.iOS, .tvOS])),
            ]
        ),
        .testTarget(
            name: "ObservabilityTests",
            dependencies: [
                "LaunchDarklyOtel",
                "LaunchDarklyObservability",
                "JSONExporters"
            ]
        ),
        .target(
            name: "LaunchDarklySessionReplay",
            dependencies: [
                "Common",
                "LaunchDarklyOtel",
                "LaunchDarklyObservability",
                "SessionReplayC",
            ],
        ),
        .target(
          name: "JSONExporters",
          dependencies: [
            .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
          ],
          path: "Sources/OpenTelemetry/JSONExporters"
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
        .target(
              name: "SDKResourceExtension",
              dependencies: [
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")],
              path: "Sources/OpenTelemetry/Instrumentation/SDKResourceExtension",
              exclude: ["README.md"]
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
                "LaunchDarklyOtel",
                "LaunchDarklyObservability",
                "SessionReplayC",
            ]
        ),
    ]
)
