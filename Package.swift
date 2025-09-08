// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-launchdarkly-observability",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "LaunchDarklyObservability",
            targets: ["LaunchDarklyObservability"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "2.0.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", from: "9.15.0"),
        .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.3.0"),
    ],
    targets: [
        .target(name: "Common"),
        .target(
            name: "API",
            dependencies: [
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
            ]
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
            name: "Observability",
            dependencies: [
                "Common",
                "API",
                "CrashReporter",
                "CrashReporterLive",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
            ]
        ),
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "Observability",
                "API",
                "Common",
                .product(name: "LaunchDarkly", package: "ios-client-sdk"),
            ]
        )
    ]
)
