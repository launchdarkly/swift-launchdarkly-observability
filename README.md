# swift-launchdarkly-observability
LaunchDarkly Observability SDK for Swift

## Early Access Preview️
**NB: APIs are subject to change until a 1.x version is released.**

## Features

### Automatic Instrumentation

The iOS observability plugin automatically instruments:
- **Activity Lifecycle**: App lifecycle events and transitions
- **HTTP Requests**: URLSession requests
- **Crash Reporting**: Automatic crash reporting
- **Feature Flag Evaluations**: Evaluation events added to your spans.
- **Session Management**: User session tracking and background timeout handling

## Example Application

A complete example application is available in the [swift-launchdarkly-observability/ExampleApp](/ExampleApp) directory.

## Install

Add the Swift Package dependency in Xcode or

## Adding as a dependency

**NOTE: since APIs are subject to change until a 1.x version is released, pointing to main branch is a temporal workaround to test/use the package**
LaunchDarkly Observability is designed for Swift 5. To depend on the swift-launchdarkly-observability package, you need to add it in your `Package.swift` as follows:

```swift
.package(url: "https://github.com/launchdarkly/swift-launchdarkly-observability", branch: "main"),
```

## Usage

### Basic Setup

Add the observability plugin to your LaunchDarkly iOS Client SDK configuration:

```swift
import UIKit
import LaunchDarkly
import LaunchDarklyObservability

let mobileKey = "your-mobile-key"
let config = { () -> LDConfig in
    var config = LDConfig(
        mobileKey: mobileKey,
        autoEnvAttributes: .enabled
    )
    config.plugins = [
        Observability(options: .init(sessionBackgroundTimeout: 3))
    ]
    return config
}()

let context = { () -> LDContext in
    var contextBuilder = LDContextBuilder(
        key: "12345"
    )
    contextBuilder.kind("user")
    do {
        return try contextBuilder.build().get()
    } catch {
        abort()
    }
}()

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        LDClient.start(
            config: config,
            context: context,
            startWaitSeconds: 5.0,
            completion: { (timedOut: Bool) -> Void in
                if timedOut {
                    // Client may not have the most recent flags for the configured context
                } else {
                    // Client has received flags for the configured context
                }
            }
        )
        return true
    }
}
```

### Configure Session Replay
```
```

### Advanced Configuration

You can customize the observability plugin with various options:

```swift
import UIKit
import LaunchDarkly
import LaunchDarklyObservability

let config = { () -> LDConfig in
    var config = LDConfig(
        mobileKey: mobileKey,
        autoEnvAttributes: .enabled
    )
    config.plugins = [
        Observability(
            options: .init(
                serviceName: "ios-app",
                serviceVersion: "0.1.0",
                resourceAttributes: [
                    "environment": .string("production"),
                    "team": .string("mobile")
                ],
                customHeaders: [
                    ("X-Custom-Header", "custom-value")
                ],
                sessionBackgroundTimeout: 60,
                isDebug: true
            )
        )
    ]
    return config
}()
```

### Recording Observability Data

After initialization of the LaunchDarkly iOS Client SDK, use `LDObserve` to record metrics, logs, errors, and traces:

```swift
import LaunchDarklyObservability
import OpenTelemetryApi

// Record metrics
LDObserve.shared.recordMetric(metric: .init(name: "user_actions", value: 1.0))
LDObserve.shared.recordCount(metric: .init(name: "api_calls", value: 1.0))
LDObserve.shared.recordIncr(metric: .init(name: "page_views", value: 1.0))
LDObserve.shared.recordHistogram(metric: .init(name: "response_time", value: 150.0))
LDObserve.shared.recordUpDownCounter(metric: .init(name: "active_connections", value: 1.0))

// Record logs
LDObserve.shared.recordLog(
    message: "User performed action",
    severity: .info,
    attributes: [
        "user_id": .string("12345"),
        "action": .string("button_click")
    ]
)

// Record errors
LDObserve.shared.recordError(
    error: paymentError,
    attributes: [
        "component": .string("payment"),
        "error_code": .string("PAYMENT_FAILED")
    ]
)

// Create spans for tracing
let span = LDObserve.shared.startSpan(
    name: "api_request",
    attributes: [
        "endpoint": .string("/api/users"),
        "method": .string("GET")
    ]
)

span.end()
```

## Contributing

We encourage pull requests and other contributions from the community. Check out our [contributing guidelines](../../CONTRIBUTING.md) for instructions on how to contribute to this SDK.

## About LaunchDarkly

* LaunchDarkly is a continuous delivery platform that provides feature flags as a service and allows developers to iterate quickly and safely. We allow you to easily flag your features and manage them from the LaunchDarkly dashboard.  With LaunchDarkly, you can:
    * Roll out a new feature to a subset of your users (like a group of users who opt-in to a beta tester group), gathering feedback and bug reports from real-world use cases.
    * Gradually roll out a feature to an increasing percentage of users, and track the effect that the feature has on key metrics (for instance, how likely is a user to complete a purchase if they have feature A versus feature B?).
    * Turn off a feature that you realize is causing performance problems in production, without needing to re-deploy, or even restart the application with a changed configuration file.
    * Grant access to certain features based on user attributes, like payment plan (eg: users on the ‘gold’ plan get access to more features than users in the ‘silver’ plan). Disable parts of your application to facilitate maintenance, without taking everything offline.
* LaunchDarkly provides feature flag SDKs for a wide variety of languages and technologies. Read [our documentation](https://docs.launchdarkly.com/sdk) for a complete list.
* Explore LaunchDarkly
    * [launchdarkly.com](https://www.launchdarkly.com/ "LaunchDarkly Main Website") for more information
    * [docs.launchdarkly.com](https://docs.launchdarkly.com/  "LaunchDarkly Documentation") for our documentation and SDK reference guides
    * [apidocs.launchdarkly.com](https://apidocs.launchdarkly.com/  "LaunchDarkly API Documentation") for our API documentation
    * [launchdarkly.com/blog](https://launchdarkly.com/blog/  "LaunchDarkly Blog Documentation") for the latest product updates
