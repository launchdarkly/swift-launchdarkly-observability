// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-launchdarkly-observability",
    platforms: [
        .iOS(.v13)
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
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", exact: "2.0.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", branch: "v10"),
        .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.3.0"),
        .package(url: "https://github.com/mw99/DataCompression", from: "3.8.0")
    ],
    targets: [
        .target(name: "Common",
                dependencies: [
                    .product(name: "DataCompression", package: "DataCompression"),
                ]),
        .target(
            name: "Observability",
            dependencies: [
                "Common",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "Installations", package: "KSCrash"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                .product(name: "LaunchDarkly", package: "ios-client-sdk")
            ],
            resources: [
                .process("Sampling/Queries"),
            ]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "Observability",
                .product(name: "LaunchDarkly", package: "ios-client-sdk")
            ]
        ),
        .testTarget(
            name: "ObservabilityTests",
            dependencies: [
                "Observability"
            ]
        ),
        .target(
            name: "SessionReplay",
            dependencies: [
                "Common",
                "Observability",
            ],
            resources: [.process("Queries")]
        ),
        .target(
            name: "LaunchDarklySessionReplay",
            dependencies: [
                "LaunchDarklyObservability",
                "SessionReplay",
            ]
        ),
        .testTarget(
            name: "CommonTests",
            dependencies: [
                "Common"
            ],
            resources: [.process("GraphQL/Queries")]
        ),
    ]
)
