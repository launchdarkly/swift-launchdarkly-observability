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
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "2.0.0"),
        .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", from: "9.15.0"),
        .package(url: "https://github.com/kstenerud/KSCrash.git", from: "2.3.0"),
    ],
    targets: [
        .target(name: "Common"),
        .target(name: "LaunchDarklyObservability")
    ]
)
