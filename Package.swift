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
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "InMemoryExporter", package: "opentelemetry-swift"),
                .product(name: "OTelSwiftLog", package: "opentelemetry-swift"),
                .product(name: "Installations", package: "KSCrash"),
            ],
            resources: [
                .process("ObservabilityServiceLive/Resources"),
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
                "SessionReplay",
            ]
        ),
        
        /***     Tests       */
        .testTarget(
            name: "OTelInstrumentationServiceTests",
            dependencies: [
                "Observability",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "LaunchDarkly", package: "ios-client-sdk"),
            ]
        ),
//  TODO: Fix hanging sampling tests
//        .testTarget(
//            name: "SamplingLiveTests",
//            dependencies: [
//                "Observability",
//                "Common",
//                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
//                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
//                .product(name: "LaunchDarkly", package: "ios-client-sdk"),
//            ],
//            resources: [
//                .copy("Resources/Stubs/Config.json"),
//                .copy("Resources/Stubs/MinConfig.json")
//            ]
//        ),
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
                "Observability",
                "Common",
                .product(name: "LaunchDarkly", package: "ios-client-sdk"),
            ]
        )
    ]
)
