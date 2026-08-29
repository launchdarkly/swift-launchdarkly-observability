import UIKit
import LaunchDarkly
import LaunchDarklyObservability
import LaunchDarklySessionReplay


final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Which setup launch runs: standalone observability (``initIndependently()``) or observability
    /// attached to an initialized `LDClient` (``initWithFlagClient()``). Flip it to exercise the app
    /// without the flagging SDK, which also hides the menu's LDClient-driven controls.
    var isIndependent = false

    private let secrets = Bundle.main.infoDictionary ?? [:]

    private lazy var mobileKey: String = {
        guard let mobileKey = secrets["mobileKey"] as? String, !mobileKey.isEmpty else {
            fatalError("Missing mobileKey in Info.plist. See Secrets.xcconfig.example.")
        }
        return mobileKey
    }()

    private lazy var observabilityOptions = ObservabilityOptions(
        isEnabled: true,
        serviceName: "observability-ios-test-app",
        otlpEndpoint: secrets["otlpEndpoint"] as? String,
        backendUrl: secrets["backendUrl"] as? String,
        resourceAttributes: ["test-options-attribute": .string("ios-test-app")],
        sessionBackgroundTimeout: 3,
        crashReporting: .enabled
    )

    private let replayOptions = SessionReplayOptions(
        isEnabled: true,
        privacy: .init(
            maskTextInputs: true,
            maskWebViews: true,
            maskLabels: false,
            maskImages: false,
            maskAccessibilityIdentifiers: ["email-field", "password-field", "card-brand-chip", "10"]
        )
    )

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        if isIndependent {
            initIndependently()
        } else {
            initWithFlagClient()
        }

        return true
    }

    // example on creating OBS/SR with flagging sdk
    func initWithFlagClient() {
        let config = LDConfig(
            mobileKey: mobileKey,
            autoEnvAttributes: .enabled
        )

        let context = makeContext()

        let completion = { (timedOut: Bool) -> Void in
            if timedOut {
                // Client may not have the most recent flags for the configured context
            } else {
                // Client has received flags for the configured context
            }
        }
        LDClient.start(
            config: config,
            context: context,
            startWaitSeconds: 5.0,
            completion: completion
        )

        guard let ldClient = LDClient.get() else {
            fatalError("LDClient.start did not produce a client.")
        }

        // Set up before any flag is evaluated below, so the evaluation is instrumented.
        LDObserve.configure(
            ldClient: ldClient,
            context: context,
            observability: observabilityOptions,
            replay: replayOptions
        )

        flagEvaluation()
    }

    // example on creating OBS/SR without flagging
    func initIndependently() {
        LDObserve.configure(
            mobileKey: mobileKey,
            observability: observabilityOptions,
            replay: replayOptions
        )

        // No client to identify the user, so telemetry and the replay session are attributed here.
        LDObserve.shared.identify(key: "12345")
    }

    private func makeContext() -> LDContext {
        var contextBuilder = LDContextBuilder(
            key: "12345"
        )
        contextBuilder.kind("user")
        do {
            return try contextBuilder.build().get()
        } catch {
            abort()
        }
    }

    lazy var client = LDClient.get()!
    let flagKey = "feature1"
    lazy var flagObserverOwner = flagKey as LDObserverOwner

    func flagEvaluation() {
        let key = flagKey
        let value = client.boolVariation(forKey: key, defaultValue: false)
        print("sync \(key) value=", value)
        client.observe(keys: [key], owner: flagObserverOwner, handler: { changedFlags in
            if let value = changedFlags[key] {
                print("observe \(key) value=", value)
            }
        })
    }
}
