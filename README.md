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
- **Taps**: A `click` span for each tap interaction
- **Screen Views**: A `screen_view` span when a `UIViewController` appears, plus a Session Replay `Navigate` event on each screen change

## Example Application

A complete example application is available in the [swift-launchdarkly-observability/ExampleApp](/ExampleApp) directory.

## Install

> **NOTE: since APIs are subject to change until a 1.x version is released, pointing to main branch is a temporal workaround to test/use the package**

### Swift Package Manager

Add the Swift Package dependency in Xcode or add it to your `Package.swift`:

```swift
.package(url: "https://github.com/launchdarkly/swift-launchdarkly-observability", branch: "main"),
```

### CocoaPods

Add the pods to your `Podfile`:

```ruby
pod 'LaunchDarklyObservability'
pod 'LaunchDarklySessionReplay'   # optional, only if using Session Replay
```

Some transitive dependencies (e.g. LDSwiftEventSource) still declare an iOS 11.0 deployment target, which is below the minimum required by recent Xcode SDKs. Add the following `post_install` hook to your `Podfile` to raise their deployment target automatically:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 13.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
end
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

Session Replay captures user interactions and screen recordings to help you understand how users interact with your application. To enable Session Replay, add the `SessionReplay` plugin alongside the `Observability` plugin:

```swift
import UIKit
import LaunchDarkly
import LaunchDarklyObservability
import LaunchDarklySessionReplay

let mobileKey = "your-mobile-key"
let config = { () -> LDConfig in
    var config = LDConfig(
        mobileKey: mobileKey,
        autoEnvAttributes: .enabled
    )
    config.plugins = [
        // Observability plugin must be added before SessionReplay
        Observability(options: .init(
            serviceName: "ios-app",
            sessionBackgroundTimeout: 3)),
        SessionReplay(options: .init(
            isEnabled: true,
            sampleRate: 1.0,
            privacy: .init(
                maskTextInputs: true,
                maskWebViews: false,
                maskImages: false,
                maskAccessibilityIdentifiers: ["email-field", "password-field"]
            )
        ))
    ]
    return config
}()

let context = { () -> LDContext in
    var contextBuilder = LDContextBuilder(key: "12345")
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

### Manual Start

By default, Session Replay attempts to start recording as soon as the SDK is initialized if `isEnabled` is set to `true`. The `sampleRate` option controls whether that attempt actually starts recording. Use a value from `0.0` to `1.0`, where `0.0` never records and `1.0` always records.

```swift
SessionReplay(options: .init(
    isEnabled: true,
    sampleRate: 0.25,
    // ... other options
))
```

If you want to initialize Session Replay without activating recording immediately (e.g., to wait for user consent or a specific event), set `isEnabled` to `false` in the options:

```swift
SessionReplay(options: .init(
    isEnabled: false,
    // ... other options
))
```

You can then attempt to activate recording later by setting `LDReplay.shared.isEnabled` to `true`. This still applies sampling.

```swift
// From a SwiftUI View or @MainActor isolated class
LDReplay.shared.isEnabled = true
```

To inspect the outcome, use `start()` and check the returned `SessionReplayStartResult`, or read `LDReplay.shared.isRunning` to see whether Session Replay is actually recording:

```swift
let result = LDReplay.shared.start()

switch result {
case .started, .alreadyStarted:
    // Session Replay is running.
case .sampledOut:
    // Session Replay is enabled, but this session was not selected by sampleRate.
case .unavailable:
    // Session Replay has not been registered.
}

let isRecording = LDReplay.shared.isRunning
```

For debugging, you can bypass sampling for a manual start:

```swift
LDReplay.shared.start(ignoreSampling: true)
```

#### Privacy Options

Configure privacy settings to control what data is captured:

- **maskTextInputs**: Mask all text input fields (default: `true`)
- **maskWebViews**: Mask contents of Web Views (default: `false`)
- **maskLabels**: Mask all text labels (default: `false`)
- **maskImages**: Mask all images (default: `false`)
- **maskAccessibilityIdentifiers**: Array of accessibility identifiers to mask
- **maskUIViews**: Array of UIView classes to mask
- **minimumAlpha**: Minimum alpha value for view visibility (default: `0.02`)

#### Fine-grained Masking Control

You can override the default privacy settings on individual views using modifiers:

**SwiftUI Views:**
```swift
import SwiftUI
import LaunchDarklySessionReplay

struct ContentView: View {
    var body: some View {
        VStack {
            // Mask this specific view
            Text("Sensitive information")
                .ldMask()

            // Unmask this view (even if it would be masked by default)
            Image("profile-photo")
                .ldUnmask()

            // Conditionally mask based on a flag
            TextField("Email", text: $email)
                .ldPrivate(isEnabled: shouldMaskEmail)
        }
    }
}
```

**UIKit Views:**
```swift
import UIKit
import LaunchDarklySessionReplay

class CreditCardViewController: UIViewController {
    let cvvField = UITextField()
    let nameField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Mask the CVV container
        cvvField.ldMask()

        // Unmask the name field (even if text inputs are masked by default)
        nameField.ldUnmask()

        // Conditionally mask based on a flag
        cvvField.ldPrivate(isEnabled: true)
    }
}
```

#### How the SDK Determines What to Mask

When deciding whether a specific view should be masked in a Session Replay, the SDK evaluates rules in a strict order of precedence. It checks these conditions from top to bottom and stops at the first one that applies:

1. **Explicit Masking (Highest Priority)**: Is the view, or *any* of its parent views, explicitly masked (e.g., using `.ldMask()` or matching `maskAccessibilityIdentifiers`)?
   * **Yes**: The view is **masked**. This overrides all other rules.
2. **Explicit Unmasking**: Is the view, or *any* of its parent views, explicitly unmasked (e.g., using `.ldUnmask()`)?
   * **Yes**: The view is **unmasked**.
3. **Global Configuration**: Does your global privacy configuration (like `maskTextInputs`, `maskImages`, etc.) apply to this view?
   * **Yes**: The view follows the global configuration.

*Note: If multiple rules conflict at the same level, masking wins over unmasking.*

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
                isDebug: true,
                analytics: .enabled
            )
        )
    ]
    return config
}()
```

`analytics` controls analytics telemetry, emitted as OpenTelemetry spans:

- `taps` (default `.enabled`): emit a `click` span for each tap. Session Replay capture is unaffected by this flag.
- `trackEvents` (default `.enabled`): emit a `track` span when a custom event is tracked, either automatically via the LaunchDarkly `afterTrack` hook (`LDClient.track(...)`) or manually via `LDObserve.shared.track(...)`.
- `screenViews` (default `.enabled`): emit a `screen_view` span when a screen is shown. This flag only gates the span — it does **not** control screen detection.

Use the `.enabled` / `.disabled` presets, or configure fields individually with `Analytics(taps:trackEvents:screenViews:)`.

`instrumentation` controls automatic instrumentation. Most features default to `.disabled`, except:

- `screens` (default `.enabled`): automatically detect screen changes by swizzling `UIViewController`. This drives the automatic `screen_view` span (gated separately by `analytics.screenViews`) and Session Replay `Navigate` events. Set it to `.disabled` to turn off automatic screen detection while still allowing manual `trackScreenView(...)` calls.

```swift
Observability(
    options: .init(
        instrumentation: .init(screens: .disabled),     // turn off automatic screen detection
        analytics: .init(screenViews: .disabled)         // or keep detection on but suppress the span
    )
)
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

// Record a custom track event as a `track` span.
// (Calling LDClient.get()?.track(key:) records the same span automatically via the afterTrack hook.)
LDObserve.shared.track(
    key: "checkout_completed",
    data: ["currency": "USD"],
    metricValue: 42.0
)
```

### Tracking Screen Views

A `screen_view` event captures when a screen is shown, using the `event.*` attribute namespace (`event.name`, `event.screen_class`, `event.screen_id`, `event.previous_screen`, `event.category`). `previous_screen` is resolved automatically from a shared screen stack, so it stays correct regardless of whether a screen was captured automatically or manually.

Each recorded screen change also produces a Session Replay `Navigate` event (mirroring the web SDK), so the replay timeline reflects navigation.

#### Automatic capture (UIKit)

When `instrumentation.screens` is enabled (the default), the SDK swizzles `UIViewController` and records a `screen_view` whenever a view controller appears. Container/system controllers (e.g. `UINavigationController`, `UITabBarController`) are skipped.

To customize how a controller is reported, conform it to `LDScreenNameProviding`:

```swift
import LaunchDarklyObservability

final class CheckoutViewController: UIViewController, LDScreenNameProviding {
    var ldScreenName: String? { "Checkout" }
    var ldScreenCategory: String? { "Commerce" }
}
```

#### Manual capture

Pure SwiftUI navigation (e.g. `NavigationStack` destinations) is not observed by the `UIViewController` swizzle, so record those screens manually.

In SwiftUI, use the `trackScreen` modifier on the screen's root view. A single call per screen is enough — `previous_screen` is resolved from the shared stack:

```swift
import SwiftUI
import LaunchDarklyObservability

struct ProfileView: View {
    var body: some View {
        VStack {
            // ...
        }
        .trackScreen("Profile", category: "Account")
    }
}
```

##### Navigation stacks and modals

`trackScreen` records on `.onAppear`, which SwiftUI does **not** re-run when you pop back to a screen in a `NavigationStack`, or when a presented `sheet` / `fullScreenCover` is dismissed. For those cases use the path- and presentation-aware modifiers so back-navigation and modal returns are tracked correctly.

Apply `trackScreenStack` to the `NavigationStack` itself, passing the same `path` binding. The top of the path (or the `root` name when the path is empty) is recorded on first appearance and on every push/pop. Return `nil` from `destination` to skip a screen that already records itself.

```swift
import SwiftUI
import LaunchDarklyObservability

struct RootView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            // ...
        }
        .trackScreenStack(path, root: "Home") { route in
            switch route {
            case .profile: return "Profile"
            case .settings: return "Settings"
            }
        }
    }
}
```

Apply `trackScreenReturn` to a presenting screen to re-emit it once a modal closes. Pass the flag (or a combination of flags) that drives the presentations; the screen is recorded on each `true` -> `false` transition:

```swift
struct RootView: View {
    @State private var activeSheet: Sheet?

    var body: some View {
        List { /* ... */ }
            .sheet(item: $activeSheet) { sheet in /* ... */ }
            // `activeSheet != nil` is true while any sheet is up; re-emits "Home" once it closes.
            .trackScreenReturn("Home", isPresented: activeSheet != nil)
    }
}
```

> Driving presentations from a single optional/enum route (e.g. `sheet(item:)`) keeps `isPresented` to one expression. If you must use multiple `sheet(isPresented:)` flags, combine them: `isPresented: a || b || c`.

Both modifiers require iOS 14 / macOS 11 / tvOS 14 / watchOS 7 or later.

Or call the API directly from anywhere after the SDK is initialized:

```swift
import LaunchDarklyObservability

LDObserve.shared.trackScreenView(
    name: "Profile",
    screenClass: "ProfileView",
    screenId: "MyApp.ProfileView",
    category: "Account"
)

// Convenience overloads:
LDObserve.shared.trackScreenView(name: "Profile")
LDObserve.shared.trackScreenView(name: "Profile", category: "Account")
```

Manual `trackScreenView(...)` calls work even when automatic detection (`instrumentation.screens`) is disabled. The emitted `screen_view` span is still gated by `analytics.screenViews`.

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
