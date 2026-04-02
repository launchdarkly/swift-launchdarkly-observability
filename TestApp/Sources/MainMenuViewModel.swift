import Foundation
import LaunchDarkly
import LaunchDarklyObservability

final class MainMenuViewModel: ObservableObject {
	@Published var isNetworkInProgress: Bool = false
	
	func recordError() {
		LDObserve.shared.recordError(
			error: Failure.crash,
			attributes: [:]
		)
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
			let span0 = LDObserve.shared.startSpan(name: "NestedSpan", attributes: ["test-true": .bool(true),
                                                                                    "test-double": .double(3.14)])
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
	
	func recordLogs() {
		LDObserve.shared.recordLog(
			message: "logs-button-pressed",
			severity: .info,
			attributes: [
				"test-string": .string("maui"),
				"test-true": .bool(true),
				"test-false": .bool(false),
				"test-integer": .int(42),
				"test-double": .double(3.14),
				"test-array": .array(.init(values: [.double(3.14)])),
				"test-nested": .set(.init(labels: ["array": .array(.init(values: [.int(1)]))]))
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

