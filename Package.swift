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
        .target(
            name: "DomainModels"
        ),
        .target(
            name: "DomainServices",
            dependencies: [
                "DomainModels"
            ]
        ),
        .target(
            name: "ApplicationServices",
            dependencies: [
                "DomainModels",
                "DomainServices"
            ]
        ),
        .target(
            name: "SessionServiceLive",
            dependencies: [
                "DomainModels",
                "DomainServices",
                "ApplicationServices"
            ]
        ),
        .target(
            name: "OTelInstrumentationService",
            dependencies: [
                "Common",
                "DomainModels",
                "DomainServices",
                "ApplicationServices",
                "Sampling",
                "SamplingLive",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
            ]
        ),
        .testTarget(
            name: "OTelInstrumentationServiceTests",
            dependencies: [
                "OTelInstrumentationService",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
            ]
        ),
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
            name: "Instrumentation",
            dependencies: [
                "API",
                "CrashReporter",
                "Sampling",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
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
                "Instrumentation",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
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
