// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-launchdarkly-observability",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "LaunchDarklyObservability",
            targets: ["LaunchDarklyObservability"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", exact: "2.0.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", from: "9.15.0"),
        .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.3.0"),
    ],
    targets: [
        .target(name: "Common"),
        .target(
            name: "API",
            dependencies: [
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
            ]
        ),
        .testTarget(
            name: "CommonTests",
            dependencies: [
                "Common"
            ],
            resources: [.process("GraphQL/Queries")]
        ),
        .target(name: "CrashReporter"),
        .target(
            name: "CrashReporterLive",
            dependencies: [
                "CrashReporter",
                "Common",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "Installations", package: "KSCrash")
            ]
        ),
        .target(
            name: "SessionReplay",
            dependencies: [
                "Common"
            ],
            resources: [.process("Queries")]
        ),
        .target(
            name: "Sampling",
            dependencies: [
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ]
        ),
        .target(
            name: "SamplingLive",
            dependencies: [
                "Sampling",
                "Common",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ]
        ),
        .testTarget(
            name: "SamplingLiveTests",
            dependencies: [
                "Sampling",
                "SamplingLive",
                "Common",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ],
            resources: [
                .copy("Resources/Stubs/Config.json"),
                .copy("Resources/Stubs/MinConfig.json")
            ]
        ),
        .target(
            name: "Observability",
            dependencies: [
                "Common",
                "API",
                "CrashReporter",
                "CrashReporterLive",
                "Sampling",
                "SamplingLive",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
            ],
            resources: [
                .copy("Resources/Config.json"),
            ]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "SessionReplay",
                "Observability",
                "API",
                "Common",
                .product(name: "LaunchDarkly", package: "ios-client-sdk"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
            ]
        )
    ]
)
