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
            name: "iOSSessionService",
            dependencies: [
                "DomainModels",
                "DomainServices",
                "ApplicationServices"
            ]
        ),
        .target(
            name: "KSCrashReportService",
            dependencies: [
                "DomainModels",
                "DomainServices",
                "ApplicationServices",
                .product(name: "Installations", package: "KSCrash")
            ]
        ),
        .target(
            name: "OTelInstrumentation",
            dependencies: [
                "Common",
                "DomainModels",
                "DomainServices",
                "ApplicationServices",
                "Sampling",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "InMemoryExporter", package: "opentelemetry-swift"),
                .product(name: "OTelSwiftLog", package: "opentelemetry-swift"),   
            ]
        ),
        .testTarget(
            name: "OTelInstrumentationServiceTests",
            dependencies: [
                "OTelInstrumentation",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
            ]
        ),
        .target(
            name: "SystemMetricsLive",
            dependencies: [
                "DomainModels",
                "DomainServices",
                "ApplicationServices"
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
                "DomainModels",
                "Sampling",
                "Common",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
            ]
        ),
        .testTarget(
            name: "SamplingLiveTests",
            dependencies: [
                "DomainModels",
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
            name: "ObservabilityServiceLive",
            dependencies: [
                "ApplicationServices",
                "OTelInstrumentation",
                "KSCrashReportService",
                "iOSSessionService",
                "Sampling",
                "SamplingLive",
                "SystemMetricsLive",
                "Common"
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(name: "Common"),
        .testTarget(
            name: "CommonTests",
            dependencies: [
                "Common"
            ],
            resources: [.process("GraphQL/Queries")]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "ApplicationServices",
                "ObservabilityServiceLive",
                .product(name: "LaunchDarkly", package: "ios-client-sdk")
            ]
        )
    ]
)
