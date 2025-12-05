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
			forKey: "my-feature",
			defaultValue: false
		)
		span.end()
	}
	
	func recordCounterMetric() {
		LDObserve.shared.recordCount(
			metric: .init(
				name: "press-count",
				value: 1,
				timestamp: .now
			)
		)
	}
	
	func recordLogs() {
		LDObserve.shared.recordLog(
			message: "logs-button-pressed",
			severity: .info,
			attributes: ["testuser": .string("andrey")]
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
    
    func identity() {
        do {
            var contextBuilder = LDContextBuilder(
                key: "test-app-key"
            )
            contextBuilder.kind("user")
            contextBuilder.trySetValue("firstName", "Bob")
            contextBuilder.trySetValue("lastName", "Bobberson")
            contextBuilder.anonymous(true)
            let newContext = try contextBuilder.build().get()
            _ = LDClient.get()?.identify(context: newContext) { result in
                print("result=", result)
            }
        } catch {
            // ignore errors for demo
        }
    }
}

