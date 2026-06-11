import Foundation
import LaunchDarkly
import LaunchDarklyObservability

final class MainMenuViewModel: ObservableObject {
	@Published var isNetworkInProgress: Bool = false
	private var screenViewCounter = 0
	
	func recordError() {
		LDObserve.shared.recordError(Failure.crash, attributes: [:])
	}
	
	func recordSpanAndVariation() {
		let span = LDObserve.shared.startSpan(
			name: "button-pressed",
			attributes: [:]
		)
		_ = LDClient.get()?.boolVariation(
			forKey: "feature1",
			defaultValue: false
		)
        
		span.end()
	}

	func triggerNestedSpans() {
		Task {
			let span0 = LDObserve.shared.startSpan(name: "NestedSpan", properties: ["test-true": true,
                                                                                    "test-double": 3.14])
			await OpenTelemetry.instance.contextProvider.withActiveSpan(span0) {
				let span1 = LDObserve.shared.startSpan(name: "NestedSpan1", attributes: [:])
				await OpenTelemetry.instance.contextProvider.withActiveSpan(span1) {
					let span2 = LDObserve.shared.startSpan(name: "NestedSpan2", attributes: [:])
					await OpenTelemetry.instance.contextProvider.withActiveSpan(span2) {
                        LDObserve.shared.recordCount(metric: .init(name: "NestedCounter", value: 10.0))
                        LDObserve.shared.recordLog(message: "NestedLog", severity: .info, attributes: [:])
						await Self.fetchURLsForNestedSpanDemo()
                        span2.end()
					}
					span1.end()
				}
				span0.end()
			}
		}
	}

	private static func fetchURLsForNestedSpanDemo() async {
		guard let google = URL(string: "https://www.google.com"),
		      let android = URL(string: "https://www.android.com/") else { return }
		_ = try? await URLSession.shared.data(from: google)
		_ = try? await URLSession.shared.data(from: android)
	}
	
	func recordMetric() {
		LDObserve.shared.recordMetric(
			metric: .init(name: "test-gauge", value: 50.0)
		)
	}

	func recordHistogramMetric() {
		LDObserve.shared.recordHistogram(
			metric: .init(name: "test-histogram", value: 15.0)
		)
	}

	func recordCounterMetric() {
		LDObserve.shared.recordCount(
			metric: .init(name: "test-counter", value: 10.0)
		)
	}

	func recordIncrementalMetric() {
		LDObserve.shared.recordIncr(
			metric: .init(name: "test-incremental-counter", value: 12.0)
		)
	}

	func recordUpDownCounterMetric() {
		LDObserve.shared.recordUpDownCounter(
			metric: .init(name: "test-up-down-counter", value: 25.0)
		)
	}
	
	func recordLogWithContext() {
		let span = LDObserve.shared.startSpan(
			name: "log-context-demo",
			properties: ["demo": "log-with-context"]
		)
		let capturedContext = span.context
		span.end()

		// Simulate a detached task where OTel context is lost automatically.
		DispatchQueue.global(qos: .background).async {
			LDObserve.shared.recordLog(
				message: "Log with span context",
				severity: .warn,
				properties: ["source": "detached-queue-demo"],
				spanContext: capturedContext
			)
		}
	}

	func recordLogs() {
		LDObserve.shared.recordLog(
			message: "logs-button-pressed",
			severity: .info,
			properties: [
				"test-string": "swift",
				"test-true": true,
				"test-false": false,
				"test-integer": 42,
				"test-long": 9_000_000_000,
				"test-double": 3.14,
				"test-array": [3.14],
				"test-nested": ["array": [1]]
			]
		)
	}
	
	func trackViaLDClient() {
		// Records a track span automatically via the Observability afterTrack hook.
		LDClient.get()?.track(
            key: "track-via-ld-client",
            data: [
                "test-string": "ios",
                "test-true": true,
                "test-false": false,
                "test-integer": .number(42),
                "test-double": 3.14,
                "test-long-number": .number(9_000_000_000_123),
            ]
        )
	}

	func trackViaLDObserve() {
		// Records a track span directly through the Observability API.
		LDObserve.shared.track(
			key: "track-via-ld-observe",
            properties: [
                "test-string": "ios",
                "test-true": true,
                "test-false": false,
                "test-integer": 42,
                // A 64-bit value beyond Int32 range (e.g. epoch nanoseconds),
                // demonstrating that long integers survive conversion.
                "test-long": 9_000_000_000_123,
                "test-double": 3.14,
                "test-swiftmap": ["test-string": "val"]
            ]
		)
	}

	func trackNested() {
		// A nested `track` payload following the Segment "Checkout Started"
		// example from analytics-taxonomy.md (§4.2): scalar fields plus a
		// `products` array of line-item objects.
		LDObserve.shared.track(
			key: "checkout-started",
			properties: [
				"name": "Checkout Started",
				"order_id": "ord_5521",
				"value": 72.0,
				"currency": "USD",
				"products": [
					["product_id": "SKU-1234", "quantity": 2, "price": 24.0],
					["product_id": "SKU-9876", "quantity": 1, "price": 24.0]
				]
			]
		)
	}

	func trackScreenView() {
		// Records a screen_view span manually; previous_screen is resolved through
		// the same shared screen stack used by automatic capture.
		screenViewCounter += 1
		LDObserve.shared.trackScreenView(
			name: "Manual Demo Screen \(screenViewCounter)",
			screenClass: "MainMenuView",
			screenId: "main-menu-demo-\(screenViewCounter)",
			category: "Demo",
			properties: [
				"source": "manual-demo",
				"index": screenViewCounter
			]
		)
	}

	func crash() -> Never {
		fatalError()
	}
	
	@MainActor
	func performNetworkRequest() async {
		guard !isNetworkInProgress else { return }
		isNetworkInProgress = true
		defer { isNetworkInProgress = false }
		
		let url = URL(string: "https://launchdarkly.com/")!
		do {
			_ = try await URLSession.shared.data(from: url)
		} catch {
			// ignore errors for demo
		}
	}
    
    func identifyUser() {
        do {
            var contextBuilder = LDContextBuilder(
                key: "single-userkey"
            )
            contextBuilder.kind("user")
            contextBuilder.trySetValue("firstName", "Bob")
            contextBuilder.trySetValue("lastName", "Bobberson")
            let newContext = try contextBuilder.build().get()
            _ = LDClient.get()?.identify(context: newContext) { result in
                print("result=", result)
            }
        } catch {
            print(error)
        }
    }
    
    func identifyAnonymous() {
        do {
            var contextBuilder = LDContextBuilder()
            contextBuilder.anonymous(false)
            let newContext = try contextBuilder.build().get()
            _ = LDClient.get()?.identify(context: newContext) { result in
                print("result=", result)
            }
        } catch {
            print(error)
        }
    }
    
    func identifyMulti() {
        let username = "multi-username"
        let id = "654321"
        var userBuilder = LDContextBuilder(key: username)
        userBuilder.kind("user")
        userBuilder.name(username)
        userBuilder.anonymous(false)
        userBuilder.trySetValue("customerNumber", .string(id))
        userBuilder.trySetValue("firstName", "Bob")
        userBuilder.trySetValue("lastName", "Bobberson")
        userBuilder.trySetValue("email", "multi@multi.com")
        
        var deviceBuilder = LDContextBuilder(key: "iphone")
        deviceBuilder.kind("device")
        deviceBuilder.name("iphone")
        deviceBuilder.anonymous(false)
        deviceBuilder.trySetValue("platform", .string("ios"))
        deviceBuilder.trySetValue("appVersion", .string("10.3.2.1"))
        
        let userContext = try? userBuilder.build().get()
        let deviceContext = try? deviceBuilder.build().get()
        
        var multiBuilder = LDMultiContextBuilder()
        multiBuilder.addContext(userContext!)
        multiBuilder.addContext(deviceContext!)
        
        let multiContext = try? multiBuilder.build().get()
        LDClient.get()?.identify(context: multiContext!) { error in
            print(error)
        }
    }
}

