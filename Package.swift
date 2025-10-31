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
        .library(
            name: "StartupMetrics",
            type: .static, // static library ensures it links early
            targets: ["StartupMetrics"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", exact: "2.0.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", exact: "10.0.0"),
        .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.3.0"),
        .package(url: "https://github.com/mw99/DataCompression", from: "3.8.0")
    ],
    targets: [
        // Swift target depends on the C target
        .target(
            name: "StartupMetrics",
            dependencies: ["StartupMetricsC"]
        ),
        // C target (no Swift files here)
        .target(
            name: "StartupMetricsC",
            publicHeadersPath: "."
        ),
        .target(name: "Common",
                dependencies: [
                    .product(name: "DataCompression", package: "DataCompression"),
                ]),
        .target(
            name: "Observability",
            dependencies: [
                "Common",
                "StartupMetrics",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "Installations", package: "KSCrash", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "ResourceExtension", package: "opentelemetry-swift", condition: .when(platforms: [.iOS, .tvOS])),
                .product(name: "LaunchDarkly", package: "ios-client-sdk", condition: .when(platforms: [.iOS, .tvOS]))
            ],
            resources: [
                .process("Sampling/Queries"),
            ]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "Observability",
                .product(name: "LaunchDarkly", package: "ios-client-sdk", condition: .when(platforms: [.iOS, .tvOS]))
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
