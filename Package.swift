// swift-tools-version: 6.1
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
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.0.0"),
//        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "LaunchDarklyObservability",
            dependencies: [
                "Shared",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "StdoutExporter", package: "opentelemetry-swift"),
                .product(name: "SignPostIntegration", package: "opentelemetry-swift"),
            ]
        ),
        .testTarget(
            name: "LaunchDarklyObservabilityTests",
            dependencies: ["LaunchDarklyObservability"]
        ),
        .target(name: "Shared"),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"]
        )
    ]
)
