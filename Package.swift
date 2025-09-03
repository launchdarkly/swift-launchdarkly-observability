// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-launchdarkly-observability",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "LaunchDarklyObservability",
            targets: ["LaunchDarklyObservability", "Client", "Plugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "2.0.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", from: "9.15.0"),
        .package(url: "https://github.com/kstenerud/KSCrash.git", .upToNextMajor(from: "2.3.0")),
    ],
    targets: [
        .target(name: "Common"),
        .target(
            name: "Interfaces",
            dependencies: [
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
            ]
        ),
        .target(
            name: "API",
            dependencies: [
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
            ]
        ),
        .target(
            name: "Client",
            dependencies: [
                "API",
                "Interfaces",
                "Common",
                "CrashReporter",
                "CrashReporterLive",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "StdoutExporter", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
            ]
        ),
        .target(
            name: "Plugin",
            dependencies: [
                "API",
                "Interfaces",
                "Client",
                "LaunchDarklyObservability",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
            ]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "API",
                "Interfaces",
                "Client",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "LaunchDarkly", package: "ios-client-sdk"),
            ]
        ),
        .testTarget(
            name: "LaunchDarklyObservabilityTests",
            dependencies: ["LaunchDarklyObservability"]
        ),
        .target(
            name: "CrashReporter"
        ),
        .target(
            name: "CrashReporterLive",
            dependencies: [
                "CrashReporter",
                "Common",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "Installations", package: "KSCrash")
            ]
        )
    ]
)
